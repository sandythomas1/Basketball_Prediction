# Play Store Release Checklist

## Account and Policy
- [ ] Google Play Developer account created and verified.
- [ ] Privacy policy hosted publicly (HTTPS URL).
- [ ] IARC content rating questionnaire completed.
- [ ] Data Safety form completed (email, profile photo, usage data declared).

## Store Listing Assets
- [ ] App icon: 512x512 PNG.
- [ ] Feature graphic: 1024x500 PNG/JPG.
- [ ] At least 2 phone screenshots uploaded.
- [ ] Short description (80 chars max) finalized.
- [ ] Full description (4000 chars max) finalized.

## Suggested Listing Copy
- Short description:
  `AI-powered NBA predictions, live insights, and Pro game analysis.`
- Full description:
  `Signal Sports gives you AI-powered NBA game predictions with clear confidence tiers, injury-aware analysis, and matchup context. Track live games, review team trends, and use Signal Chat for fast game breakdowns. Free tier includes daily AI chats and core prediction access. Upgrade to Pro for unlimited chats and deeper insights.`

## Build and Submission
- [ ] `key.properties` created from `app/android/key.properties.example`.
- [ ] Release keystore generated and stored securely.
- [ ] `flutter build appbundle --release` succeeds.
- [ ] Upload AAB to internal testing track.
- [ ] Validate sign-in, RTDB reads/writes, and RevenueCat purchase flow on tester devices.
