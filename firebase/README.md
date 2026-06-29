Firebase credentials and conventions

- Do NOT commit the service account JSON.
- Add the service account JSON path to your CI secrets as `FIREBASE_SERVICE_ACCOUNT`.
- Use the Firebase emulator for local integration tests. Example:

  ```bash
  firebase emulators:start --only firestore,auth
  ```

- Store Firestore/Storage rules in `firebase.rules` or `firestore.rules` and version them.

- Example usage in CI: write the service account to a file at runtime and set `GOOGLE_APPLICATION_CREDENTIALS`.
