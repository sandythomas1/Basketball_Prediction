# Firebase Storage Rules - Deployment Instructions

## ⚠️ URGENT - Expires February 15, 2026 (4 days)

Your Firebase Storage test mode rules expire soon. The updated production-ready rules have been created and are ready to deploy.

---

## What Was Done

✅ **Created `storage.rules`** - Production-ready security rules with no expiration  
✅ **Updated `firebase.json`** - Added storage configuration  
✅ **Removed test mode expiration** - Replaced with permanent deny-by-default rule

---

## Security Rules Summary

### What's Protected:
- **Profile Photos** (`/profile_photos/{userId}`)
  - ✅ Authenticated users can view all profile photos
  - ✅ Users can only modify their own profile photo
  - ✅ File size limit: 5MB
  - ✅ File type: Images only
  - ✅ No expiration

### What's Blocked:
- ❌ All other storage paths (deny by default)
- ❌ Unauthenticated access
- ❌ Writing to other users' photos
- ❌ Non-image files
- ❌ Files over 5MB

---

## Deployment Options

### Option 1: Firebase Console (Fastest - 2 minutes)

1. **Open Firebase Console**
   - Go to: https://console.firebase.google.com
   - Select project: **NBA Predictions**

2. **Navigate to Storage Rules**
   - Click **Storage** in left sidebar
   - Click **Rules** tab at the top

3. **Replace Rules**
   - Copy the entire contents of `storage.rules` file
   - Paste into the Firebase Console editor
   - Click **Publish** button

4. **Verify**
   - Warning about expiring rules should disappear
   - Test uploading a profile photo in your app

---

### Option 2: Firebase CLI (Recommended if you use CLI)

1. **Install Firebase CLI** (if not already installed)
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**
   ```bash
   firebase login
   ```

3. **Deploy Storage Rules**
   ```bash
   firebase deploy --only storage:rules
   ```

4. **Verify Deployment**
   ```bash
   # Should show successful deployment
   # ✔ Deploy complete!
   ```

---

## Testing After Deployment

### Quick Test Checklist

1. **Profile Photo Upload (Should Work)**
   - Open your NBA Predictions app
   - Go to profile settings
   - Upload or change profile photo
   - ✅ Should succeed without errors

2. **View Other Profiles (Should Work)**
   - Navigate to another user's profile
   - Their profile photo should load
   - ✅ Should display correctly

3. **Verify in Firebase Console**
   - Go to Storage → Files
   - Check `profile_photos/` folder has files
   - No error messages in console logs

### Expected Results

```
✅ Own profile photo upload: SUCCESS
✅ Own profile photo view: SUCCESS
✅ Other users' photo view: SUCCESS
❌ Upload to wrong user path: BLOCKED (expected)
❌ Upload non-image file: BLOCKED (expected)
❌ Upload file > 5MB: BLOCKED (expected)
```

---

## What Changed?

### Before (Expiring)
```
match /{allPaths=**} {
  allow read, write: if request.time < timestamp.date(2026, 2, 15);
}
```
⚠️ This rule expires in 4 days and would break your app!

### After (Production-Ready)
```
match /{allPaths=**} {
  allow read, write: if false;
}
```
✅ Secure deny-by-default rule that never expires

---

## Troubleshooting

### Issue: "Permission denied" after deployment

**Cause:** Rules are working correctly - trying to access unauthorized path

**Solution:** Make sure your app only accesses `/profile_photos/{userId}` paths

---

### Issue: Can't upload profile photo

**Check:**
1. Is user authenticated? `FirebaseAuth.instance.currentUser != null`
2. Is file an image? Check MIME type
3. Is file under 5MB? Check file size
4. Is path correct? Should be `profile_photos/{userId}` where userId is the current user's UID

---

### Issue: Need to rollback

**Emergency Rollback** (extends test mode 30 days):

In Firebase Console, temporarily replace rules with:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.time < timestamp.date(2026, 3, 15);
    }
  }
}
```

Then investigate and fix the actual issue.

---

## Files Created/Modified

| File | Action | Description |
|------|--------|-------------|
| `storage.rules` | ✅ Created | Production-ready security rules |
| `firebase.json` | ✅ Updated | Added storage configuration |
| `FIREBASE_STORAGE_DEPLOYMENT.md` | ✅ Created | This deployment guide |

---

## Timeline

- **Right Now:** Deploy using Option 1 or Option 2 above (2-5 minutes)
- **Today:** Test thoroughly in your app
- **Day 1-2:** Monitor for any issues
- **February 15, 2026:** Old rules expire (no impact if you deployed)

---

## Deployment Verification

After deployment, confirm:

- [ ] No expiration warning in Firebase Console
- [ ] Profile photos upload successfully
- [ ] Profile photos display in app
- [ ] No errors in Firebase Console logs
- [ ] Storage usage metrics are normal

---

## Security Best Practices Applied ✅

1. ✅ **Deny by default** - All paths blocked unless explicitly allowed
2. ✅ **Authentication required** - No anonymous access
3. ✅ **Owner-only writes** - Users can only modify their own content
4. ✅ **File validation** - Size and type restrictions
5. ✅ **No expiration** - Production-ready rules that don't expire

---

## Need Help?

- **Firebase Docs:** https://firebase.google.com/docs/storage/security
- **Current Rules File:** `storage.rules` in project root
- **Firebase Console:** https://console.firebase.google.com

---

**🚨 ACTION REQUIRED: Deploy these rules before February 15, 2026 to avoid service disruption!**

**Recommended:** Use Option 1 (Firebase Console) - takes only 2 minutes and doesn't require CLI setup.
