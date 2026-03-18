# ULink Together

`ULink Together` is a volunteer management system with:

- a Rust backend in `server/`
- a teacher/admin web panel in `admin/`
- a student iPad app in `swiftui/`

This README explains how to start the backend, run the web panel, and build the student app.

## Prerequisites

- Rust stable toolchain
- Bun
- Xcode

## Repository Layout

- `server/`: backend API and database bootstrap
- `admin/`: teacher/admin web panel
- `swiftui/`: student iPad app

## 1. Start the Backend

### 1.1 Initialize the database

If you use SQLite, create the database file first:

```bash
touch together.db
```

Create tables and seed the first admin user:

```bash
cargo run -p together-server --bin deploy -- \
  --database-url sqlite://./together.db \
  --admin-email admin@example.com \
  --admin-password changeme \
  --admin-realname "Admin" \
  --admin-gender unspecified \
  --admin-classname Admin \
  --non-interactive
```

### 1.2 Run the backend on a fixed port

Choose the host based on where the student app will run:

- iPad simulator on the same Mac: bind `127.0.0.1`
- Physical iPad on the same LAN: bind `0.0.0.0`

Simulator / local web-panel setup:

```bash
cargo run -p together-server --bin together-server -- \
  --database-url sqlite://./together.db \
  --host 127.0.0.1 \
  --port 8000
```

Physical iPad setup:

```bash
cargo run -p together-server --bin together-server -- \
  --database-url sqlite://./together.db \
  --host 0.0.0.0 \
  --port 8000
```

After startup, the backend listens on port `8000`.

For local browser access on the same Mac, use:

```text
http://127.0.0.1:8000
```

If port `8000` is already occupied, either stop the conflicting process or pick another free port such as `8001`. If you change the backend port, update both:

- `VITE_BACKEND_ORIGIN` for the admin web panel
- the server URL entered in the student app login screen

## 2. Start the Teacher/Admin Web Panel

Install dependencies:

```bash
cd admin
bun install
```

Run the dev server and point it at the backend:

```bash
VITE_BACKEND_ORIGIN=http://127.0.0.1:8000 bun run dev --host 127.0.0.1 --port 4173
```

Then open:

```text
http://127.0.0.1:4173
```

Use the admin account you created in the backend bootstrap step.

### Production build

```bash
cd admin
bun run build
```

## 3. Build the Student iPad App

The student app lives in:

```text
swiftui/together.xcodeproj
```

### Option A: Build in Xcode

Open the project:

```bash
open swiftui/together.xcodeproj
```

Then:

1. Select scheme `together`
2. Choose an iPad simulator or a physical iPad
3. Build or run from Xcode

### Option B: Build from the command line

Simulator build:

```bash
xcodebuild \
  -project swiftui/together.xcodeproj \
  -scheme together \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Device build:

```bash
xcodebuild \
  -project swiftui/together.xcodeproj \
  -scheme together \
  -destination 'generic/platform=iOS' \
  build
```

Note:

- Simulator builds should work without Apple code-signing setup.
- Physical device builds require a valid Xcode signing configuration on the local machine.

## 4. Configure the Student App to Use the Backend

The SwiftUI app no longer hardcodes the backend address.

After launching the app:

1. Open the login screen
2. Enter the server URL that matches your environment:

Simulator on the same Mac:

```text
http://127.0.0.1:8000
```

Physical iPad on the same LAN:

```text
http://<your-mac-lan-ip>:8000
```

Example:

```text
http://192.168.1.23:8000
```

3. Sign in with a valid account

You can also change the server URL later from the `Account` screen and tap `Reconnect`.

## 5. Recommended Local Startup Order

1. Initialize the database
2. Start the backend on port `8000`
3. Start the admin web panel on port `4173`
4. Build and run the SwiftUI app
5. Enter the backend server URL inside the student app

## 6. Verification Commands

Backend tests:

```bash
cargo test -p together-server
```

Admin web build:

```bash
cd admin
bun run build
```

SwiftUI simulator build:

```bash
xcodebuild \
  -project swiftui/together.xcodeproj \
  -scheme together \
  -destination 'generic/platform=iOS Simulator' \
  build
```
