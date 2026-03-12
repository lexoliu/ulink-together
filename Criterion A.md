#### **Client and Scenario**

The client for this project is Ulink College of Shanghai, an IBDP world school where community service is a mandatory graduation requirement. The primary end-users are student volunteers (aged 15-19), who are proficient with school-mandated iPads, and faculty or student organizers responsible for managing events.

The current workflow for managing volunteer activities is highly fragmented and inefficient. Recruitment information is scattered across disparate platforms like DingTalk, forums, and physical posters, leading to missed opportunities for students. Organizers must use multiple, disconnected applications, manually transferring data between them, which creates delays and introduces a high risk of error. Communication is ad-hoc, requiring organizers to repetitively create new chat groups for each event. Finally, the manual calculation and entry of volunteer hours into the school's official ISMAS system is a time-consuming process prone to significant human error, compromising data integrity.

#### **Rationale for Proposed Solution**

To resolve these inefficiencies, a centralized, custom-built volunteer management system is proposed. This integrated platform is designed to directly address the core problems identified.

By consolidating all volunteer activities, the system will provide students with a single point of access for all opportunities, solving the issue of fragmented information (**Success Criterion #2**). Integrated communication channels for each activity will eliminate the repetitive setup of external chat groups and streamline organizer-volunteer interaction (**Success Criterion #4**). Crucially, the system will automate the tracking and recording of volunteer hours. This feature reduces manual calculation errors and allows the system to generate an export file matching the school's ISMAS import requirements, a key deliverable measured by **Success Criterion #6**. Additional features like an automated leaderboard will foster student engagement (**Success Criterion #5**).

The client-server architecture will use a carefully selected technology stack. The client application will be developed with **SwiftUI** to ensure a native, high-performance experience on the school's mandatory iPads (iPadOS 17.5+), as verified by **Success Criterion #7**. The server backend will use **Rust** for its memory safety and efficiency, ensuring system reliability. All data will be stored in a **PostgreSQL** relational database to maintain data integrity between users, activities, and recorded hours.

#### **Proposed Solution**

The proposed solution is a client–server volunteer management system.

- **Architecture**: The system will follow a client–server model.
    
- **Client side**: Two versions will be developed for organizers and volunteers using SwiftUI, ensuring compatibility with iPadOS.
    
- **Server side**: The backend will be developed using Rust, with PostgreSQL as the relational database.
    

#### **Success Criteria**

The success of the solution will be evaluated against the following measurable criteria:

1. **Account Registration**: A volunteer can create an account using their student information and avatar, and this data is stored securely in the database.
    
2. **Task Publication**: An organiser can publish a volunteer activity including attributes such as time, maximum participants, description, and duration, and it becomes visible to volunteers within five seconds.
    
3. **Task Management**: An organiser can edit or cancel an existing activity, and the changes are reflected immediately to all volunteers.
    
4. **Communication**: Participants can exchange messages within a channel associated with each activity, and these messages are stored in the system for future reference.
    
5. **Leaderboard**: A leaderboard displays volunteers ranked by total recorded hours, updating automatically after each activity is completed.
    
6. **Hour Tracking and Export**: The system records volunteer hours automatically after an activity is confirmed by the organiser, and it generates an export file matching the school's ISMAS import requirements.
    
7. **Platform Compatibility**: The client application runs without error on iPadOS 17.5 or later, and all primary features function as intended.
