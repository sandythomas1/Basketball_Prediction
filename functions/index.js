/**
 * Firebase Cloud Functions for NBA Predictions app
 * 
 * Scheduled function to clean up old forum messages nightly.
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.database();

/**
 * Scheduled function that runs daily at midnight UTC to delete
 * global forum messages older than 24 hours.
 * 
 * Only affects: forums/general/messages
 * Game-specific forums are not touched.
 */
exports.cleanupOldForumMessages = functions.pubsub
  .schedule('0 0 * * *')  // Run at midnight UTC every day
  .timeZone('UTC')
  .onRun(async (context) => {
    const cutoffTime = Date.now() - (24 * 60 * 60 * 1000); // 24 hours ago
    
    console.log(`Starting forum cleanup. Deleting messages older than: ${new Date(cutoffTime).toISOString()}`);
    
    const messagesRef = db.ref('forums/general/messages');
    
    try {
      // Query messages with timestamp less than cutoff
      const snapshot = await messagesRef
        .orderByChild('timestamp')
        .endAt(cutoffTime)
        .once('value');
      
      if (!snapshot.exists()) {
        console.log('No old messages to delete.');
        return null;
      }
      
      const updates = {};
      let deleteCount = 0;
      
      snapshot.forEach((child) => {
        updates[child.key] = null; // Setting to null deletes the node
        deleteCount++;
      });
      
      // Perform batch delete
      await messagesRef.update(updates);
      
      console.log(`Successfully deleted ${deleteCount} old forum messages.`);
      return null;
      
    } catch (error) {
      console.error('Error cleaning up forum messages:', error);
      throw error;
    }
  });
