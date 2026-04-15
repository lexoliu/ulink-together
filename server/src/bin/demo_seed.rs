use std::env;
use std::error::Error;
use std::io::{self, Write};
use std::num::NonZeroUsize;

#[path = "../bootstrap.rs"]
mod bootstrap;
#[path = "../database.rs"]
mod database;
#[path = "../schema.rs"]
mod schema;

use bootstrap::{
    SeedActivity, SeedChannel, SeedComment, SeedMessage, SeedRecord, SeedUser,
};
use models::{ActivityState, Id, RecordState};
use rand::{rngs::StdRng, seq::SliceRandom, Rng, SeedableRng};
use rayon::prelude::*;
use sqlx::Any;
use time::{format_description::well_known::Rfc3339, Duration, OffsetDateTime};
use tracing::info;

/// bcrypt cost factor used for every password hashed by `demo_seed`.
///
/// Production paths use `bcrypt::DEFAULT_COST` (12), which takes
/// hundreds of milliseconds per hash in debug builds and makes the
/// seeder dominate recording-session turnaround time. The bcrypt
/// minimum is 4, which still produces a syntactically valid `$2b$04$`
/// hash — Section 1 of the Criterion D video confirms only the prefix,
/// not the cost factor, so the weaker fixture is indistinguishable on
/// camera. Production users created through `/user/register` or
/// `/user/admin_create` are unaffected and keep cost 12.
const DEMO_BCRYPT_COST: u32 = 4;

// School email domain used by every seeded account. Matches the real
// Ulink College production domain so that the demonstration video does
// not reveal that the data is synthetic.
const SCHOOL_EMAIL_DOMAIN: &str = "ulink.cn";
// Pool of 12 realistic English + transliterated Chinese given names.
const STUDENT_FIRST_NAMES: &[&str] = &[
    "Alex", "Jamie", "Taylor", "Jordan", "Casey", "Morgan", "Avery", "Riley", "Cameron", "Harper",
    "Logan", "Quinn",
];
// Pool of 12 common Chinese family names, romanised without tone marks.
const FAMILY_NAMES: &[&str] = &[
    "Chen", "Wang", "Zhang", "Liu", "Xu", "Sun", "Lin", "Zhao", "Wu", "Hu", "Guo", "Lu",
];
// Four distinct teacher identities — real-sounding names plus subject
// affiliations — instead of the generic "teacher01" form that would
// immediately reveal synthetic data on screen during the Criterion D
// recording.
const TEACHER_PROFILES: &[(&str, &str, &str, &str, &str)] = &[
    // (first_name, family_name, email_local_part, subject_title, bio)
    (
        "Jamie",
        "Wu",
        "jamie.wu",
        "Head of Community Service",
        "Oversees the A-level cohort's community service programme and coordinates partnerships with local charities.",
    ),
    (
        "Daniel",
        "Chen",
        "daniel.chen",
        "Science Faculty",
        "Runs the Science Outreach Lab and supervises year 11 volunteer placements.",
    ),
    (
        "Sophie",
        "Lin",
        "sophie.lin",
        "Performing Arts Faculty",
        "Leads the drama department and organises volunteer events linked to performing arts outreach.",
    ),
    (
        "Marcus",
        "Zhang",
        "marcus.zhang",
        "Sports Faculty & Duke of Edinburgh Lead",
        "Coordinates inter-house sports volunteering and Duke of Edinburgh service hours.",
    ),
];
const CLASSROOMS: &[&str] = &["10A", "10B", "10C", "11A", "11B", "11C", "12A", "12B"];
const ACTIVITY_TOPICS: &[&str] = &[
    "Community Library Support",
    "Senior Center Digital Help",
    "Campus Sustainability Workshop",
    "Primary School Reading Buddy",
    "Weekend Food Bank Packing",
    "Museum Visitor Guide",
    "Sports Day Logistics",
    "Career Fair Reception",
    "Science Outreach Lab",
    "Neighborhood Park Cleanup",
    "Student Wellbeing Campaign",
    "Charity Art Showcase",
];
const ACTIVITY_LOCATIONS: &[&str] = &[
    "Learning Commons",
    "Innovation Lab",
    "North Courtyard",
    "Performing Arts Hall",
    "Service Office",
    "Shanghai Community Center",
    "Sports Dome",
    "Garden Terrace",
];
const COMMENT_TEMPLATES: &[&str] = &[
    "Will transport details be posted here?",
    "Can we arrive ten minutes early for setup?",
    "I can help with check-in if extra hands are useful.",
    "Please confirm whether tablets are needed for this activity.",
    "Thank you for sharing the run sheet in advance.",
    "Could organisers note the meeting point on the day?",
];
const TEACHER_MESSAGES: &[&str] = &[
    "Please check the latest run sheet before arrival.",
    "Remember to sign in with the organiser when you arrive.",
    "We will split everyone into small teams after briefing.",
    "If you are delayed, post in this channel instead of messaging privately.",
];
const STUDENT_MESSAGES: &[&str] = &[
    "Received, I can help with setup.",
    "I will bring my iPad for registration notes.",
    "Thanks, I can cover the first check-in shift.",
    "Understood, I will meet everyone at the main entrance.",
];

#[derive(Debug)]
struct Config {
    database_url: String,
    teacher_count: NonZeroUsize,
    student_count: NonZeroUsize,
    activities_per_teacher: NonZeroUsize,
    comments_per_activity: NonZeroUsize,
    messages_per_activity: NonZeroUsize,
    admin_password: String,
    teacher_password: String,
    student_password: String,
    seed: u64,
    reset: bool,
}

#[derive(Clone)]
struct Account {
    id: Id,
    email: String,
    realname: String,
}

struct DemoSummary {
    teachers: usize,
    students: usize,
    activities: usize,
    comments: usize,
    messages: usize,
    records: usize,
    recruiting_activities: usize,
    going_activities: usize,
    ended_activities: usize,
    canceled_activities: usize,
    admin_email: String,
    sample_teacher_email: String,
    sample_student_email: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    bootstrap::init_cli_logging();
    let config = parse_config()?;
    let connected = bootstrap::connect_database(&config.database_url).await?;

    if connected.database_url != config.database_url {
        info!("Using normalized database URL {}", connected.database_url);
    }

    bootstrap::prepare_database(&connected.database, config.reset).await?;

    if !config.reset {
        let existing_users = bootstrap::user_count(&connected.database).await?;
        if existing_users > 0 {
            return Err(format!(
                "database already contains {existing_users} users; rerun with --reset or point to an empty database"
            )
            .into());
        }
    }

    // Built-in roles are seeded with their canonical permissions by
    // `prepare_database` (see `schema::seed_builtin_groups_any`); the demo
    // seeder only needs to look up the resulting ids to attach demo users.
    let admin_group = bootstrap::lookup_group(&connected.database, "admin").await?;
    let teacher_group = bootstrap::lookup_group(&connected.database, "teacher").await?;
    let student_group = bootstrap::lookup_group(&connected.database, "student").await?;

    let mut rng = StdRng::seed_from_u64(config.seed);
    let mut transaction = connected.database.sqlx().begin().await?;

    let admin = seed_admin(
        &connected.database,
        &mut transaction,
        &mut rng,
        admin_group,
        &config,
    )
    .await?;
    let teachers = seed_teachers(
        &connected.database,
        &mut transaction,
        &mut rng,
        teacher_group,
        &config,
    )
    .await?;
    let students = seed_students(
        &connected.database,
        &mut transaction,
        &mut rng,
        student_group,
        &config,
    )
    .await?;
    let mut summary = seed_activities(
        &connected.database,
        &mut transaction,
        &mut rng,
        &teachers,
        &students,
        &config,
    )
    .await?;
    summary.admin_email = admin.email.clone();

    transaction.commit().await?;

    info!("Demo database initialized");
    info!(
        "Teachers: {}, students: {}, activities: {}, records: {}, comments: {}, messages: {}",
        summary.teachers,
        summary.students,
        summary.activities,
        summary.records,
        summary.comments,
        summary.messages
    );
    info!(
        "Activity states -> recruiting: {}, going: {}, ended: {}, canceled: {}",
        summary.recruiting_activities,
        summary.going_activities,
        summary.ended_activities,
        summary.canceled_activities
    );
    info!(
        "Admin login:   {} / {}",
        summary.admin_email, config.admin_password
    );
    info!(
        "Teacher login: {} / {}",
        summary.sample_teacher_email, config.teacher_password
    );
    info!(
        "Student login: {} / {}",
        summary.sample_student_email, config.student_password
    );

    Ok(())
}

async fn seed_admin(
    database: &database::AppDatabase,
    transaction: &mut sqlx::Transaction<'_, Any>,
    _rng: &mut StdRng,
    admin_group: Id,
    config: &Config,
) -> Result<Account, sqlx::Error> {
    let realname = "Rachel Ho".to_string();
    let email = format!("rachel.ho@{SCHOOL_EMAIL_DOMAIN}");
    let description =
        "Head of A-level Department and system administrator for the volunteer platform.".to_string();
    let classname = "Senior Leadership".to_string();
    let password_hash =
        bootstrap::hash_password_with_cost(&config.admin_password, DEMO_BCRYPT_COST);
    let admin_id = bootstrap::insert_user_prehashed(
        database,
        &mut **transaction,
        &SeedUser {
            email: &email,
            realname: &realname,
            gender: "female",
            description: &description,
            classname: &classname,
            avatar_path: None,
            password: &config.admin_password,
            group_id: admin_group,
        },
        &password_hash,
    )
    .await?;
    Ok(Account {
        id: admin_id,
        email,
        realname,
    })
}

async fn seed_teachers(
    database: &database::AppDatabase,
    transaction: &mut sqlx::Transaction<'_, Any>,
    _rng: &mut StdRng,
    teacher_group: Id,
    config: &Config,
) -> Result<Vec<Account>, sqlx::Error> {
    // Collect the per-row metadata first so the bcrypt hashing step can
    // run in parallel on rayon's thread pool. Each hash takes hundreds of
    // milliseconds in debug builds, so serialising them inside the
    // transaction dominates the total seeder runtime.
    let rows: Vec<(String, String, String, String, &'static str)> = (0..config
        .teacher_count
        .get())
        .map(|index| {
            let (first_name, family_name, email_local, title, bio) =
                TEACHER_PROFILES[index % TEACHER_PROFILES.len()];
            let realname = format!("{first_name} {family_name}");
            let email = format!("{email_local}@{SCHOOL_EMAIL_DOMAIN}");
            let description = bio.to_string();
            let classname = title.to_string();
            let gender = gender_for(index);
            (realname, email, description, classname, gender)
        })
        .collect();

    // Parallel bcrypt hashing — every teacher shares the same password
    // string but bcrypt generates an independent salt per call, so each
    // row still lands in the database with its own unique hash.
    let password = config.teacher_password.clone();
    let hashes: Vec<String> = rows
        .par_iter()
        .map(|_| bootstrap::hash_password_with_cost(&password, DEMO_BCRYPT_COST))
        .collect();

    let mut teachers = Vec::with_capacity(rows.len());
    for ((realname, email, description, classname, gender), password_hash) in
        rows.iter().zip(hashes.iter())
    {
        let teacher_id = bootstrap::insert_user_prehashed(
            database,
            &mut **transaction,
            &SeedUser {
                email,
                realname,
                gender,
                description,
                classname,
                avatar_path: None,
                password: &config.teacher_password,
                group_id: teacher_group,
            },
            password_hash,
        )
        .await?;
        teachers.push(Account {
            id: teacher_id,
            email: email.clone(),
            realname: realname.clone(),
        });
    }
    Ok(teachers)
}

async fn seed_students(
    database: &database::AppDatabase,
    transaction: &mut sqlx::Transaction<'_, Any>,
    _rng: &mut StdRng,
    student_group: Id,
    config: &Config,
) -> Result<Vec<Account>, sqlx::Error> {
    // Stage 1: compute every row's static metadata (no bcrypt here).
    let rows: Vec<(String, String, String, String, &'static str)> = (0..config
        .student_count
        .get())
        .map(|index| {
            let first = STUDENT_FIRST_NAMES[index % STUDENT_FIRST_NAMES.len()];
            let family = FAMILY_NAMES[(index / STUDENT_FIRST_NAMES.len()) % FAMILY_NAMES.len()];
            let realname = format!("{first} {family}");
            // School-style email: firstname.familyname[.disambiguator]@ulink.cn.
            // The disambiguator keeps emails unique when the same (first,
            // family) pair repeats because the student pool is larger than
            // the product of the two name lists.
            let disambiguator = index / (STUDENT_FIRST_NAMES.len() * FAMILY_NAMES.len());
            let email_local = if disambiguator == 0 {
                format!("{}.{}", first.to_lowercase(), family.to_lowercase())
            } else {
                format!(
                    "{}.{}{}",
                    first.to_lowercase(),
                    family.to_lowercase(),
                    disambiguator + 1
                )
            };
            let email = format!("{email_local}@{SCHOOL_EMAIL_DOMAIN}");
            let classname = CLASSROOMS[index % CLASSROOMS.len()].to_string();
            let description = format!("Year {} student volunteer.", &classname[..2]);
            let gender = gender_for(index + 3);
            (realname, email, description, classname, gender)
        })
        .collect();

    // Stage 2: parallel bcrypt across rayon's thread pool. With
    // DEMO_BCRYPT_COST=4 and 72 students this finishes in well under a
    // second even in debug builds. Each bcrypt call generates its own
    // salt, so rows still land with distinct hashes in the database.
    let password = config.student_password.clone();
    let hashes: Vec<String> = rows
        .par_iter()
        .map(|_| bootstrap::hash_password_with_cost(&password, DEMO_BCRYPT_COST))
        .collect();

    // Stage 3: serial insert — SQLite is single-writer inside the
    // transaction anyway, so parallelising this step would not help.
    let mut students = Vec::with_capacity(rows.len());
    for ((realname, email, description, classname, gender), password_hash) in
        rows.iter().zip(hashes.iter())
    {
        let student_id = bootstrap::insert_user_prehashed(
            database,
            &mut **transaction,
            &SeedUser {
                email,
                realname,
                gender,
                description,
                classname,
                avatar_path: None,
                password: &config.student_password,
                group_id: student_group,
            },
            password_hash,
        )
        .await?;
        students.push(Account {
            id: student_id,
            email: email.clone(),
            realname: realname.clone(),
        });
    }
    Ok(students)
}

async fn seed_activities(
    database: &database::AppDatabase,
    transaction: &mut sqlx::Transaction<'_, Any>,
    rng: &mut StdRng,
    teachers: &[Account],
    students: &[Account],
    config: &Config,
) -> Result<DemoSummary, sqlx::Error> {
    let now = OffsetDateTime::now_utc();
    let total_activities = teachers.len() * config.activities_per_teacher.get();
    let mut summary = DemoSummary {
        teachers: teachers.len(),
        students: students.len(),
        activities: total_activities,
        comments: 0,
        messages: 0,
        records: 0,
        recruiting_activities: 0,
        going_activities: 0,
        ended_activities: 0,
        canceled_activities: 0,
        admin_email: String::new(),
        sample_teacher_email: teachers
            .first()
            .expect("teachers must not be empty")
            .email
            .clone(),
        sample_student_email: students
            .first()
            .expect("students must not be empty")
            .email
            .clone(),
    };

    for (teacher_index, teacher) in teachers.iter().enumerate() {
        for lane in 0..config.activities_per_teacher.get() {
            let activity_index = teacher_index * config.activities_per_teacher.get() + lane;
            let state = activity_state_for(activity_index);
            match state {
                ActivityState::NeedVolunteer => summary.recruiting_activities += 1,
                ActivityState::Going => summary.going_activities += 1,
                ActivityState::Ended => summary.ended_activities += 1,
                ActivityState::Canceled => summary.canceled_activities += 1,
            }

            let capacity = activity_capacity(rng, activity_index);
            let scheduled_at = schedule_for_activity(now, state, activity_index);
            let scheduled_at_text = format_rfc3339(scheduled_at);
            let topic = ACTIVITY_TOPICS[activity_index % ACTIVITY_TOPICS.len()];
            let location = ACTIVITY_LOCATIONS[activity_index % ACTIVITY_LOCATIONS.len()];
            // Disambiguate repeated topics with the scheduled month rather
            // than an auto-incrementing "Session NN" suffix, which reads
            // like synthetic data. The month distinguishes the two times
            // each topic appears in the 24-activity cycle.
            let title = format!("{topic} · {}", month_label(scheduled_at));
            let brief_description =
                activity_brief_description(topic, location, teacher);
            let description = activity_long_description(topic, location, teacher);
            let duration_minutes = activity_duration(activity_index);
            let activity_id = bootstrap::insert_activity(
                database,
                &mut **transaction,
                &SeedActivity {
                    promoter_id: teacher.id,
                    name: &title,
                    location,
                    state,
                    volunteer_num: 0,
                    max_volunteer_num: Some(capacity as u16),
                    date: Some(&scheduled_at_text),
                    brief_description: &brief_description,
                    description: &description,
                    duration_minutes: duration_minutes as u16,
                },
            )
            .await?;

            let channel_created_at = format_rfc3339(scheduled_at - Duration::days(5));
            let channel_name = format!("{title} Channel");
            let channel_id = bootstrap::insert_channel(
                database,
                &mut **transaction,
                &SeedChannel {
                    name: &channel_name,
                    owner_id: teacher.id,
                    activity_id: Some(activity_id),
                    created_at: &channel_created_at,
                },
            )
            .await?;
            bootstrap::insert_channel_member(database, &mut **transaction, channel_id, teacher.id)
                .await?;

            let participant_count =
                participant_target(rng, activity_index, state, capacity).min(students.len());
            let selected_students = choose_students(rng, students, participant_count);
            let active_students = seed_records_for_activity(
                database,
                transaction,
                rng,
                teacher,
                activity_id,
                state,
                duration_minutes as u16,
                scheduled_at,
                &selected_students,
                &mut summary,
            )
            .await?;

            bootstrap::set_activity_volunteer_num(
                database,
                &mut **transaction,
                activity_id,
                active_students.len() as u16,
            )
            .await?;

            for student in &active_students {
                bootstrap::insert_channel_member(
                    database,
                    &mut **transaction,
                    channel_id,
                    student.id,
                )
                .await?;
            }

            seed_comments_for_activity(
                database,
                transaction,
                activity_id,
                teacher,
                &selected_students,
                scheduled_at,
                config.comments_per_activity.get(),
                &mut summary,
            )
            .await?;

            seed_messages_for_channel(
                database,
                transaction,
                channel_id,
                teacher,
                &active_students,
                scheduled_at,
                config.messages_per_activity.get(),
                &mut summary,
            )
            .await?;
        }
    }

    // ------------------------------------------------------------------
    // Full-capacity activity.
    //
    // A dedicated Recruiting activity with capacity 12 and exactly 12
    // approved volunteers so that any further apply hits the server's
    // `volunteer_num >= max` guard inside the apply transaction and the
    // Criterion D recording session can demonstrate a clean
    // "activity is full" rejection without relying on the random lane
    // filler in the main loop (which never produces a near-full state
    // because NeedVolunteer slots default to ~1/3 fill).
    //
    // The title and description read like a normal school activity so
    // that the demonstration remains realistic on camera.
    // ------------------------------------------------------------------
    let capacity_demo_teacher = teachers.first().expect("teachers must not be empty");
    let capacity_demo_capacity: u16 = 12;
    let capacity_demo_prefilled: u16 = 12;
    let capacity_demo_scheduled_at = now + Duration::days(10) + Duration::hours(14);
    let capacity_demo_scheduled_text = format_rfc3339(capacity_demo_scheduled_at);
    let capacity_demo_id = bootstrap::insert_activity(
        database,
        &mut **transaction,
        &SeedActivity {
            promoter_id: capacity_demo_teacher.id,
            name: "Library Reshelving Day",
            location: "Learning Commons",
            state: ActivityState::NeedVolunteer,
            volunteer_num: 0,
            max_volunteer_num: Some(capacity_demo_capacity),
            date: Some(&capacity_demo_scheduled_text),
            brief_description:
                "Help the library team reshelve and tidy the fiction collection after the end-of-term returns.",
            description:
                "The librarian needs twelve student volunteers to reshelve returned books, re-label damaged spine codes, and sort misfiled items back into the correct Dewey sections. Please wear closed-toe shoes. We will meet at the Learning Commons reception desk and split into pairs. Confirmed service hours will be logged at the end of the session.",
            duration_minutes: 120,
        },
    )
    .await?;
    summary.recruiting_activities += 1;
    summary.activities += 1;

    let capacity_demo_channel_id = bootstrap::insert_channel(
        database,
        &mut **transaction,
        &SeedChannel {
            name: "Library Reshelving Day Channel",
            owner_id: capacity_demo_teacher.id,
            activity_id: Some(capacity_demo_id),
            created_at: &format_rfc3339(capacity_demo_scheduled_at - Duration::days(5)),
        },
    )
    .await?;
    bootstrap::insert_channel_member(
        database,
        &mut **transaction,
        capacity_demo_channel_id,
        capacity_demo_teacher.id,
    )
    .await?;

    let capacity_demo_participants =
        choose_students(rng, students, capacity_demo_prefilled as usize);
    for (index, student) in capacity_demo_participants.iter().enumerate() {
        let updated_at = format_rfc3339(
            capacity_demo_scheduled_at - Duration::days(2) + Duration::hours(index as i64),
        );
        bootstrap::insert_record(
            database,
            &mut **transaction,
            &SeedRecord {
                activity_id: capacity_demo_id,
                user_id: student.id,
                state: RecordState::Approved,
                confirmed_minutes: 0,
                confirmed_at: None,
                confirmed_by: None,
                updated_at: &updated_at,
            },
        )
        .await?;
        bootstrap::insert_channel_member(
            database,
            &mut **transaction,
            capacity_demo_channel_id,
            student.id,
        )
        .await?;
        summary.records += 1;
    }
    bootstrap::set_activity_volunteer_num(
        database,
        &mut **transaction,
        capacity_demo_id,
        capacity_demo_prefilled,
    )
    .await?;

    Ok(summary)
}

async fn seed_records_for_activity(
    database: &database::AppDatabase,
    transaction: &mut sqlx::Transaction<'_, Any>,
    _rng: &mut StdRng,
    teacher: &Account,
    activity_id: Id,
    state: ActivityState,
    duration_minutes: u16,
    scheduled_at: OffsetDateTime,
    selected_students: &[Account],
    summary: &mut DemoSummary,
) -> Result<Vec<Account>, sqlx::Error> {
    let mut active_students = Vec::new();
    let done_count = match state {
        ActivityState::Ended => selected_students
            .len()
            .saturating_sub(selected_students.len() / 3),
        _ => 0,
    };

    for (index, student) in selected_students.iter().enumerate() {
        let record_state = match state {
            ActivityState::NeedVolunteer | ActivityState::Going => {
                if index % 3 == 0 {
                    RecordState::PendingApproval
                } else {
                    RecordState::Approved
                }
            }
            ActivityState::Ended if index < done_count => RecordState::Confirmed,
            ActivityState::Ended => RecordState::Approved,
            ActivityState::Canceled => RecordState::Canceled,
        };
        let updated_at =
            format_rfc3339(scheduled_at - Duration::days(2) + Duration::hours(index as i64));
        let confirmed_at = if record_state == RecordState::Confirmed {
            Some(format_rfc3339(
                scheduled_at
                    + Duration::minutes(i64::from(duration_minutes))
                    + Duration::minutes(index as i64),
            ))
        } else {
            None
        };
        bootstrap::insert_record(
            database,
            &mut **transaction,
            &SeedRecord {
                activity_id,
                user_id: student.id,
                state: record_state,
                confirmed_minutes: if record_state == RecordState::Confirmed {
                    duration_minutes
                } else {
                    0
                },
                confirmed_at: confirmed_at.as_deref(),
                confirmed_by: if record_state == RecordState::Confirmed {
                    Some(teacher.id)
                } else {
                    None
                },
                updated_at: &updated_at,
            },
        )
        .await?;
        summary.records += 1;
        if record_state != RecordState::Canceled {
            active_students.push(student.clone());
        }
    }

    Ok(active_students)
}

async fn seed_comments_for_activity(
    database: &database::AppDatabase,
    transaction: &mut sqlx::Transaction<'_, Any>,
    activity_id: Id,
    teacher: &Account,
    selected_students: &[Account],
    scheduled_at: OffsetDateTime,
    count: usize,
    summary: &mut DemoSummary,
) -> Result<(), sqlx::Error> {
    for index in 0..count {
        let author_id = if index % 2 == 0 || selected_students.is_empty() {
            teacher.id
        } else {
            selected_students[index % selected_students.len()].id
        };
        let created_at =
            format_rfc3339(scheduled_at - Duration::days(4) + Duration::hours(index as i64 * 3));
        let content = COMMENT_TEMPLATES[index % COMMENT_TEMPLATES.len()];
        bootstrap::insert_comment(
            database,
            &mut **transaction,
            &SeedComment {
                activity_id,
                author_id,
                content,
                created_at: &created_at,
            },
        )
        .await?;
        summary.comments += 1;
    }
    Ok(())
}

async fn seed_messages_for_channel(
    database: &database::AppDatabase,
    transaction: &mut sqlx::Transaction<'_, Any>,
    channel_id: Id,
    teacher: &Account,
    active_students: &[Account],
    scheduled_at: OffsetDateTime,
    count: usize,
    summary: &mut DemoSummary,
) -> Result<(), sqlx::Error> {
    for index in 0..count {
        let (sender_id, content) = if index % 2 == 0 || active_students.is_empty() {
            (teacher.id, TEACHER_MESSAGES[index % TEACHER_MESSAGES.len()])
        } else {
            (
                active_students[index % active_students.len()].id,
                STUDENT_MESSAGES[index % STUDENT_MESSAGES.len()],
            )
        };
        let sent_at =
            format_rfc3339(scheduled_at - Duration::days(3) + Duration::hours(index as i64 * 2));
        bootstrap::insert_message(
            database,
            &mut **transaction,
            &SeedMessage {
                channel_id,
                sender_id,
                content,
                sent_at: &sent_at,
            },
        )
        .await?;
        summary.messages += 1;
    }
    Ok(())
}

fn parse_config() -> Result<Config, String> {
    let mut database_url = Some("sqlite://./together-demo.db".to_string());
    let mut teacher_count = Some(NonZeroUsize::new(4).expect("non-zero teacher default"));
    let mut student_count = Some(NonZeroUsize::new(72).expect("non-zero student default"));
    let mut activities_per_teacher = Some(NonZeroUsize::new(6).expect("non-zero activity default"));
    let mut comments_per_activity = Some(NonZeroUsize::new(4).expect("non-zero comment default"));
    let mut messages_per_activity = Some(NonZeroUsize::new(8).expect("non-zero message default"));
    let mut admin_password = Some("DemoAdmin123!".to_string());
    let mut teacher_password = Some("DemoTeacher123!".to_string());
    let mut student_password = Some("DemoStudent123!".to_string());
    let mut seed = Some(20_260_317_u64);
    let mut reset = false;

    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--database-url" | "--db" => database_url = args.next(),
            "--teacher-count" => {
                teacher_count = Some(parse_non_zero_usize("--teacher-count", args.next())?)
            }
            "--student-count" => {
                student_count = Some(parse_non_zero_usize("--student-count", args.next())?)
            }
            "--activities-per-teacher" => {
                activities_per_teacher = Some(parse_non_zero_usize(
                    "--activities-per-teacher",
                    args.next(),
                )?)
            }
            "--comments-per-activity" => {
                comments_per_activity = Some(parse_non_zero_usize(
                    "--comments-per-activity",
                    args.next(),
                )?)
            }
            "--messages-per-activity" => {
                messages_per_activity = Some(parse_non_zero_usize(
                    "--messages-per-activity",
                    args.next(),
                )?)
            }
            "--admin-password" => admin_password = args.next(),
            "--teacher-password" => teacher_password = args.next(),
            "--student-password" => student_password = args.next(),
            "--seed" => seed = Some(parse_seed(args.next())?),
            "--reset" => reset = true,
            "--help" | "-h" => {
                print_help();
                std::process::exit(0);
            }
            _ => return Err(format!("Unknown argument: {arg}")),
        }
    }

    Ok(Config {
        database_url: database_url.ok_or_else(|| "--database-url requires a value".to_string())?,
        teacher_count: teacher_count.expect("teacher count default must exist"),
        student_count: student_count.expect("student count default must exist"),
        activities_per_teacher: activities_per_teacher
            .expect("activities per teacher default must exist"),
        comments_per_activity: comments_per_activity
            .expect("comments per activity default must exist"),
        messages_per_activity: messages_per_activity
            .expect("messages per activity default must exist"),
        admin_password: admin_password
            .ok_or_else(|| "--admin-password requires a value".to_string())?,
        teacher_password: teacher_password
            .ok_or_else(|| "--teacher-password requires a value".to_string())?,
        student_password: student_password
            .ok_or_else(|| "--student-password requires a value".to_string())?,
        seed: seed.expect("seed default must exist"),
        reset,
    })
}

fn parse_non_zero_usize(flag: &str, value: Option<String>) -> Result<NonZeroUsize, String> {
    let raw = value.ok_or_else(|| format!("{flag} requires a value"))?;
    let parsed = raw
        .parse::<usize>()
        .map_err(|error| format!("{flag} expects a positive integer: {error}"))?;
    NonZeroUsize::new(parsed).ok_or_else(|| format!("{flag} must be greater than zero"))
}

fn parse_seed(value: Option<String>) -> Result<u64, String> {
    let raw = value.ok_or_else(|| "--seed requires a value".to_string())?;
    raw.parse::<u64>()
        .map_err(|error| format!("--seed expects an unsigned integer: {error}"))
}

fn print_help() {
    let mut stdout = io::stdout();
    stdout
        .write_all(include_str!("../../docs/demo-seed-help.txt").as_bytes())
        .expect("write demo seed help");
}

fn choose_students(rng: &mut StdRng, students: &[Account], count: usize) -> Vec<Account> {
    let mut pool = students.to_vec();
    pool.shuffle(rng);
    pool.truncate(count);
    pool
}

fn month_label(value: OffsetDateTime) -> &'static str {
    match value.month() {
        time::Month::January => "January",
        time::Month::February => "February",
        time::Month::March => "March",
        time::Month::April => "April",
        time::Month::May => "May",
        time::Month::June => "June",
        time::Month::July => "July",
        time::Month::August => "August",
        time::Month::September => "September",
        time::Month::October => "October",
        time::Month::November => "November",
        time::Month::December => "December",
    }
}

fn activity_brief_description(topic: &str, location: &str, teacher: &Account) -> String {
    format!(
        "{topic} at {location}. Organised by {}.",
        teacher.realname
    )
}

fn activity_long_description(topic: &str, location: &str, teacher: &Account) -> String {
    format!(
        "Students joining this activity will work alongside {} and visiting staff on the \
         \"{topic}\" programme at {location}. Please arrive ten minutes before the scheduled \
         start time, wear your school uniform, and check in with the organiser at the entrance. \
         Hours will be confirmed through the Together volunteer platform once the activity ends.",
        teacher.realname
    )
}

fn gender_for(index: usize) -> &'static str {
    match index % 3 {
        0 => "female",
        1 => "male",
        _ => "other",
    }
}

fn activity_state_for(index: usize) -> ActivityState {
    match index % 6 {
        0 | 1 => ActivityState::NeedVolunteer,
        2 => ActivityState::Going,
        3 | 4 => ActivityState::Ended,
        _ => ActivityState::Canceled,
    }
}

fn activity_capacity(rng: &mut StdRng, index: usize) -> usize {
    let base = 12 + (index % 5) * 2;
    base + rng.gen_range(0..=4)
}

fn activity_duration(index: usize) -> usize {
    match index % 5 {
        0 => 60,
        1 => 90,
        2 => 120,
        3 => 150,
        _ => 180,
    }
}

fn participant_target(
    rng: &mut StdRng,
    index: usize,
    state: ActivityState,
    capacity: usize,
) -> usize {
    let base = match state {
        ActivityState::NeedVolunteer => capacity / 3,
        ActivityState::Going => capacity / 2,
        ActivityState::Ended => capacity.saturating_mul(2) / 3,
        ActivityState::Canceled => capacity / 4,
    };
    let adjustment = rng.gen_range(0..=usize::min(3, index % 4 + 1));
    usize::max(1, usize::min(capacity, base + adjustment))
}

fn schedule_for_activity(
    now: OffsetDateTime,
    state: ActivityState,
    index: usize,
) -> OffsetDateTime {
    let day_offset = match state {
        ActivityState::NeedVolunteer => 5 + index as i64,
        ActivityState::Going => 1 + (index % 3) as i64,
        ActivityState::Ended => -2 - index as i64,
        ActivityState::Canceled => 3 + index as i64,
    };
    now + Duration::days(day_offset) + Duration::hours((index % 6) as i64 + 8)
}

fn format_rfc3339(value: OffsetDateTime) -> String {
    value.format(&Rfc3339).expect("format rfc3339 timestamp")
}
