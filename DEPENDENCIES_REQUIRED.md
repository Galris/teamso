# TeamUp – dependency and deployment notes

The uploaded archive did not include `pubspec.yaml`, so package versions already used by the app could not be audited. The Firebase Core, Auth and Firestore packages are assumed to be present as stated in the handoff. This patch adds a callable Cloud Functions client dependency:

```bash
flutter pub add cloud_functions
flutter pub get
```

The app also continues to use the existing `http`, `flutter_secure_storage`, and `url_launcher` dependencies. Do not upgrade unrelated packages without checking the full project's lockfile.

## Firebase Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

Callable functions added:
- `joinProjectByCode`: securely validates a join code and creates membership + user membership index.
- `getProjectMembers`: returns only public member profile fields to authenticated project members; it does not return email or phone.
- `deleteProject`: deletes a project and its subcollections, then removes membership indexes.

## Firestore

Deploy rules and indexes from the project root:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

The rules intentionally allow a user to read only their own `users/{uid}` document. Member cards are loaded through the callable function to avoid exposing email and phone fields to every signed-in user.
