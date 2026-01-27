/**
 * Firebase Cloud Functions for NBA Predictions app
 * 
 * - Scheduled function to clean up old forum messages nightly
 * - AI Agent proxy for secure Dialogflow CX communication
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { SessionsClient } = require('@google-cloud/dialogflow-cx');

admin.initializeApp();

const db = admin.database();

// =============================================================================
// AI Agent Configuration
// =============================================================================

// Agent config from Firebase Functions config or environment
// Set with: firebase functions:config:set agent.project_id="xxx" agent.agent_id="xxx"
// Or uses defaults for this project
const AGENT_CONFIG = {
  projectId: functions.config().agent?.project_id || process.env.GCP_PROJECT_ID || 'nba-predictions-29e45',
  location: functions.config().agent?.location || process.env.GCP_LOCATION || 'global',
  agentId: functions.config().agent?.agent_id || process.env.GCP_AGENT_ID || 'f034d8e9-09e6-4afd-b528-31af050510fe',
  languageCode: 'en',
};

// Initialize Dialogflow CX client
const sessionsClient = new SessionsClient({
  apiEndpoint: `${AGENT_CONFIG.location}-dialogflow.googleapis.com`,
});

// =============================================================================
// AI Agent Chat Function
// =============================================================================

/**
 * Cloud Function to proxy requests to Dialogflow CX agent.
 * Requires Firebase Authentication.
 * 
 * Request body:
 * {
 *   "message": "What's the prediction for Lakers vs Celtics?",
 *   "sessionId": "optional-session-id",
 *   "gameContext": { optional game data }
 * }
 */
exports.chatWithAgent = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to chat with the AI assistant.'
    );
  }

  const { message, sessionId, gameContext } = data;

  if (!message || typeof message !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Message is required and must be a string.'
    );
  }

  // Use provided sessionId or create one from user's UID
  const finalSessionId = sessionId || `user-${context.auth.uid}-${Date.now()}`;

  // Build the session path
  const sessionPath = sessionsClient.projectLocationAgentSessionPath(
    AGENT_CONFIG.projectId,
    AGENT_CONFIG.location,
    AGENT_CONFIG.agentId,
    finalSessionId
  );

  // Build the message with optional game context
  let fullMessage = message;
  if (gameContext) {
    fullMessage = `[GAME CONTEXT]
Home: ${gameContext.homeTeam} (Elo: ${gameContext.homeElo || 1500})
Away: ${gameContext.awayTeam} (Elo: ${gameContext.awayElo || 1500})
Home Win Prob: ${((gameContext.homeWinProb || 0.5) * 100).toFixed(1)}%
Confidence: ${gameContext.confidenceTier || 'Moderate'}

[USER QUESTION]
${message}`;
  }

  try {
    // Send request to Dialogflow CX
    const request = {
      session: sessionPath,
      queryInput: {
        text: {
          text: fullMessage,
        },
        languageCode: AGENT_CONFIG.languageCode,
      },
    };

    const [response] = await sessionsClient.detectIntent(request);
    
    // Extract response messages
    const responseMessages = response.queryResult.responseMessages || [];
    let agentResponse = '';
    
    for (const msg of responseMessages) {
      if (msg.text && msg.text.text) {
        agentResponse += msg.text.text.join('\n');
      }
    }

    return {
      success: true,
      response: agentResponse || 'I could not generate a response. Please try again.',
      sessionId: finalSessionId,
      confidence: response.queryResult.intentDetectionConfidence,
    };

  } catch (error) {
    console.error('Dialogflow CX error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get response from AI assistant. Please try again.'
    );
  }
});

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
