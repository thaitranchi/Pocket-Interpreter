# Pricing — Pocket Interpreter

## Business model

**Completely free — everything unlocked.**

Pocket Interpreter has no ads, no subscriptions, and no in-app purchases. Every feature is
available from the first launch, including all speech model profiles (`tiny` / `base` /
`small`), push-to-talk, continuous mode, live subtitles, and offline translation.

## Feature availability

| Feature | Included |
|---|---|
| Real-time voice interpretation (push-to-talk) | ✅ |
| Continuous / hands-free mode | ✅ |
| Live subtitles with spoken translation playback | ✅ |
| All offline speech model profiles (`tiny` / `base` / `small`) | ✅ |
| On-device ML Kit translation | ✅ |
| Voice activity detection (energy gate) | ✅ |
| Conversation history with latency metadata | ✅ |
| Ads | None |
| Subscriptions / in-app purchases | None |

## Notes

- The app is private by design: no account, no analytics, no advertising ID.
- Network access is used only to download the offline speech and ML Kit translation models
  on first use.
- There is no billing integration in the codebase; adding one would require reintroducing a
  billing SDK and entitlement gating.
