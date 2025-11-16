use waterui::widget::suspense::Suspense;
use waterui::{prelude::*, task::spawn_local};

use crate::models::{
    ActivityDetail, ActivityFilters, ActivitySummary, Comment, CreateActivityPayload, RecordState,
    VolunteerRosterEntry,
};
use crate::state::{AppContext, AppRoute, AuthScreen, AuthStatus};

pub fn activity_detail(ctx: AppContext, id: String) -> AnyView {
    AnyView::new(Suspense::new(load_activity_detail(ctx, id)))
}

async fn load_activity_detail(ctx: AppContext, id: String) -> AnyView {
    match ctx.api().get_activity(&id).await {
        Ok(detail) => {
            let comments = ctx.api().list_comments(&id).await.unwrap_or_default();
            AnyView::new(render_activity_detail(ctx, id, detail, comments))
        }
        Err(err) => AnyView::new(error_view(err)),
    }
}

fn render_activity_detail(
    ctx: AppContext,
    activity_id: String,
    detail: ActivityDetail,
    comments: Vec<Comment>,
) -> impl View {
    let detail_binding = Binding::container(detail);
    let comments_binding = Binding::container(comments);
    let comment_text = Binding::container(Str::default());

    vstack((
        Dynamic::watch(detail_binding.clone(), |activity| {
            activity_summary(activity.clone())
        }),
        join_button(ctx.clone(), activity_id.clone(), detail_binding.clone()),
        comment_section(ctx, activity_id, comments_binding, comment_text),
    ))
}

fn activity_summary(activity: ActivityDetail) -> impl View {
    let limit = activity
        .max_volunteer_num
        .map(|max| max.to_string())
        .unwrap_or_else(|| "open".into());
    card(vstack((
        text(activity.name).size(22.0),
        text(activity.location),
        text(activity.description),
        text(format!(
            "Volunteers: {} / {}",
            activity.volunteer_num, limit
        )),
    )))
}

fn join_button(ctx: AppContext, activity_id: String, detail: Binding<ActivityDetail>) -> impl View {
    Dynamic::watch(ctx.session(), move |session| {
        match (session.status, session.uid.clone()) {
            (AuthStatus::Ready, Some(uid)) => {
                let already = detail.get().volunteers.contains(&uid);
                if already {
                    AnyView::new(text("You have joined this activity"))
                } else {
                    let detail_binding = detail.clone();
                    let ctx_clone = ctx.clone();
                    let uid_clone = uid.clone();
                    let activity_value = activity_id.clone();
                    AnyView::new(button("Join").action_with(
                        &detail_binding,
                        move |binding: Binding<ActivityDetail>| {
                            let ctx = ctx_clone.clone();
                            let uid = uid_clone.clone();
                            let activity = activity_value.clone();
                            spawn_local(async move {
                                if ctx.api().join_activity(&activity).await.is_ok() {
                                    let mut snapshot = binding.get();
                                    if !snapshot.volunteers.contains(&uid) {
                                        snapshot.volunteers.push(uid.clone());
                                        snapshot.volunteer_num += 1;
                                        binding.set(snapshot);
                                    }
                                }
                            });
                        },
                    ))
                }
            }
            (AuthStatus::Loading, _) => AnyView::new(text("Checking account...")),
            _ => {
                let ctx = ctx.clone();
                AnyView::new(
                    button("Login to join")
                        .action(move || ctx.set_route(AppRoute::Auth(AuthScreen::Login))),
                )
            }
        }
    })
}

fn comment_section(
    ctx: AppContext,
    activity_id: String,
    comments: Binding<Vec<Comment>>,
    comment_binding: Binding<Str>,
) -> impl View {
    let submit_feedback = Binding::container(String::new());
    vstack((
        text("Comments").size(20.0),
        Dynamic::watch(comments.clone(), |list| {
            if list.is_empty() {
                AnyView::new(text("No comments yet"))
            } else {
                let views: VStack<_> = list
                    .into_iter()
                    .map(|comment| card(vstack((text(comment.author_name), text(comment.content)))))
                    .collect();
                AnyView::new(views)
            }
        }),
        Dynamic::watch(submit_feedback.clone(), |message| {
            if message.is_empty() {
                spacer().anyview()
            } else {
                AnyView::new(text(message))
            }
        }),
        super::require_login(ctx.clone(), move |ctx, uid| {
            let comments_binding = comments.clone();
            let text_binding = comment_binding.clone();
            let feedback = submit_feedback.clone();
            let activity_value = activity_id.clone();
            AnyView::new(vstack((
                field("Comment", &text_binding),
                button("Send").action_with(&feedback, move |status: Binding<String>| {
                    let ctx = ctx.clone();
                    let comments_binding = comments_binding.clone();
                    let text_binding = text_binding.clone();
                    let activity = activity_value.clone();
                    let uid = uid.clone();
                    spawn_local(async move {
                        let content = text_binding.get().to_string();
                        if content.trim().is_empty() {
                            status.set(String::from("Comment cannot be empty"));
                            return;
                        }
                        match ctx.api().post_comment(&activity, content.trim()).await {
                            Ok(_) => {
                                status.set(String::from("Comment sent"));
                                let mut list = comments_binding.get();
                                list.push(Comment {
                                    id: String::new(),
                                    author: uid.clone(),
                                    author_name: "Me".into(),
                                    content,
                                    date: String::new(),
                                });
                                comments_binding.set(list);
                                text_binding.set(Str::default());
                            }
                            Err(err) => status.set(err.to_string()),
                        }
                    });
                }),
            )))
        }),
    ))
}

pub fn manage_list(ctx: AppContext) -> AnyView {
    AnyView::new(super::require_login(ctx.clone(), move |ctx, uid| {
        AnyView::new(Suspense::new(load_manage_list(ctx, uid)))
    }))
}

async fn load_manage_list(ctx: AppContext, uid: String) -> AnyView {
    let filters = ActivityFilters {
        user: Some(uid),
        display_all: true,
    };
    match ctx.api().list_activities(&filters).await {
        Ok(activities) => {
            let cards: VStack<_> = activities
                .into_iter()
                .map(|activity| manage_card(ctx.clone(), activity))
                .collect();
            let ctx_create = ctx.clone();
            AnyView::new(vstack((
                button("Create activity")
                    .action(move || ctx_create.set_route(AppRoute::CreateActivity)),
                scroll(cards),
            )))
        }
        Err(err) => AnyView::new(error_view(err)),
    }
}

fn manage_card(ctx: AppContext, activity: ActivitySummary) -> impl View {
    let activity_id = activity.id.clone();
    let ctx_manage = ctx.clone();
    card(vstack((
        text(activity.name).size(18.0),
        text(activity.location),
        button("Manage").action(move || ctx_manage.open_manage_activity(activity_id.clone())),
    )))
}

pub fn manage_activity(ctx: AppContext, id: String) -> AnyView {
    AnyView::new(super::require_login(ctx.clone(), move |ctx, _| {
        AnyView::new(Suspense::new(load_manage_activity(ctx, id.clone())))
    }))
}

async fn load_manage_activity(ctx: AppContext, id: String) -> AnyView {
    match ctx.api().get_activity(&id).await {
        Ok(detail) => {
            let roster = ctx
                .api()
                .fetch_volunteer_roster(&id, &detail.volunteers)
                .await;
            match roster {
                Ok(entries) => AnyView::new(render_roster(ctx, detail, entries)),
                Err(err) => AnyView::new(error_view(err)),
            }
        }
        Err(err) => AnyView::new(error_view(err)),
    }
}

fn render_roster(
    ctx: AppContext,
    detail: ActivityDetail,
    entries: Vec<VolunteerRosterEntry>,
) -> impl View {
    let roster_binding = Binding::container(entries);
    vstack((
        activity_summary(detail),
        Dynamic::watch(roster_binding.clone(), move |entries| {
            if entries.is_empty() {
                AnyView::new(text("No volunteers yet"))
            } else {
                let list: VStack<_> = entries
                    .into_iter()
                    .map(|entry| volunteer_row(ctx.clone(), roster_binding.clone(), entry))
                    .collect();
                AnyView::new(list)
            }
        }),
    ))
}

fn volunteer_row(
    ctx: AppContext,
    roster: Binding<Vec<VolunteerRosterEntry>>,
    entry: VolunteerRosterEntry,
) -> impl View {
    let record_id = entry.record.id.clone();
    let content = if matches!(entry.record.state, RecordState::Done) {
        AnyView::new(text("Done"))
    } else {
        let btn_state = roster.clone();
        let ctx_clone = ctx.clone();
        AnyView::new(button("Mark as done").action_with(
            &btn_state,
            move |binding: Binding<Vec<VolunteerRosterEntry>>| {
                let ctx = ctx_clone.clone();
                let record = record_id.clone();
                spawn_local(async move {
                    if ctx.api().mark_record_done(&record).await.is_ok() {
                        let mut data = binding.get();
                        if let Some(volunteer) = data.iter_mut().find(|vol| vol.record.id == record)
                        {
                            volunteer.record.state = RecordState::Done;
                        }
                        binding.set(data);
                    }
                });
            },
        ))
    };

    card(hstack((
        vstack((text(entry.user.realname), text(entry.user.classname))),
        spacer(),
        content,
    )))
}

pub fn create_activity(ctx: AppContext) -> AnyView {
    AnyView::new(super::require_login(ctx.clone(), move |ctx, _| {
        AnyView::new(activity_creator(ctx.clone()))
    }))
}

fn activity_creator(ctx: AppContext) -> impl View {
    let name = Binding::container(Str::default());
    let location = Binding::container(Str::default());
    let brief = Binding::container(Str::default());
    let description = Binding::container(Str::default());
    let duration = Binding::int(60);
    let max_volunteers = Binding::int(0);
    let date = Binding::container(Str::default());
    let feedback = Binding::container(String::new());
    vstack((
        field("Name", &name),
        field("Location", &location),
        field("Brief description", &brief),
        field("Description", &description),
        Stepper::new(&duration)
            .label(text("Duration (minutes)"))
            .range(0..=720),
        Stepper::new(&max_volunteers)
            .label(text("Max volunteers"))
            .range(0..=500),
        field("Date (YYYY-MM-DD)", &date),
        Dynamic::watch(feedback.clone(), |message| {
            if message.is_empty() {
                spacer().anyview()
            } else {
                AnyView::new(text(message))
            }
        }),
        button("Create").action_with(&feedback, move |status: Binding<String>| {
            let ctx = ctx.clone();
            let payload = CreateActivityPayload {
                name: name.get().to_string(),
                location: location.get().to_string(),
                brief_description: brief.get().to_string(),
                description: description.get().to_string(),
                duration: duration.get().max(0).min(u16::MAX as i32) as u16,
                max_volunteer_num: {
                    let value = max_volunteers.get();
                    if value <= 0 {
                        None
                    } else {
                        Some(value.min(u16::MAX as i32) as u16)
                    }
                },
                date: {
                    let value = date.get().to_string();
                    if value.trim().is_empty() {
                        None
                    } else {
                        Some(value)
                    }
                },
            };

            spawn_local(async move {
                status.set(String::new());
                match ctx.api().create_activity(payload).await {
                    Ok(response) => {
                        status.set(response.message);
                        ctx.set_route(AppRoute::ManageActivityList);
                    }
                    Err(err) => status.set(err.to_string()),
                }
            });
        }),
    ))
}

fn error_view(error: impl ToString) -> AnyView {
    AnyView::new(card(text(error.to_string())).padding_with(EdgeInsets::all(12.0)))
}
