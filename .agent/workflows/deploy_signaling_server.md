---
description: Deploy the WebRTC signaling server to Google Cloud Run
---
1. Navigate to the signaling server directory
2. Deploy to Cloud Run using the pre-configured project and region

```bash
cd signaling_server
# turbo
gcloud run deploy freegram-signaling --source . --project prototype-29c26 --region us-central1 --allow-unauthenticated
```
