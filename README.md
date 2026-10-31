# CoRide (Flutter app)

Android-first app for the carpool backend in `../carpool-backend`. Screens: login (OTP), find ride (matches along the route), offer ride (live equal-split cost), daily commute partners, my trips (pickup code, trip share, SOS, ratings), and profile (ID verification, vehicles, emergency contacts, notifications).

## Build it

You need Flutter **3.35 or newer** and the Android SDK (install Android Studio, then run `flutter doctor`).

```bash
# 1. Start the backend (in another terminal)
cd ../carpool-backend && ADMIN_PHONES=9876543210 npm start

# 2. One-time app setup
cd ../coride_app && bash setup.sh

# 3. Run on an emulator (10.0.2.2 is the emulator's address for your computer)
flutter run

#    or on a real phone on the same Wi-Fi, using your computer's IP:
flutter run --dart-define=API_URL=http://192.168.1.10:3000

# 4. Build an installable APK
flutter build apk --release --dart-define=API_URL=https://your-server.example.com
# result: build/app/outputs/flutter-apk/app-release.apk
```

## Try the whole flow

Development mode fills in the OTP for you.

1. Log in as `9876543210` (the admin). Log in as two more numbers on other emulators/phones: one driver, one passenger.
2. Each user: **Me → ID verification**, submit. Approve it in the admin panel (`http://localhost:3000/admin-panel`, **IDs** tab).
3. Driver: **Me → My vehicles → Add vehicle**, submit. Approve it in the admin panel (**Vehicles** tab).
4. Driver: **Offer** a ride, Alappuzha to Thiruvananthapuram. See the cost split change as seats fill.
5. Passenger: **Find**, search, open the ride, **Request to join**. Driver accepts in **Trips**. Passenger shows the 4-digit pickup code.

Admin work is done in the browser panel served by the backend, not in this app.

## Before this goes to real users

- **Never ship the debug build or the `http` setting.** Use HTTPS and remove `usesCleartextTraffic` for release.
- **Place search** uses a built-in list of 40 Kerala places (`lib/places.dart`). Replace with Google Places or Mapbox, and send real road distance to the API.
- **Photo upload** for ID and vehicle documents is not built; those screens take a link for now. Needs an upload endpoint with private storage.
- **Push notifications and SMS** (Firebase Cloud Messaging, an SMS provider) are not connected.
- **Live location** (driver app sending position for the trip-share link) is not built in the app yet; the API endpoint exists.
- This code has **not been compiled yet** (the build environment could not download the Flutter SDK). Expect to fix a few small compile errors on the first `flutter run`.

## No Flutter on your PC? Let GitHub build the APK

1. Make a free account at github.com and create a **new private repository**.
2. Upload everything in this `coride_app` folder to it (drag and drop in the browser, **including the hidden `.github` folder**).
3. Open the repo's **Actions** tab, choose **Build CoRide APK**, click **Run workflow**, and type your PC's address (for example `http://192.168.1.10:3000`).
4. After about 10 minutes open the finished run and download **coride-apk** at the bottom. Unzip it to get `app-release.apk`, and install it on your phone.
