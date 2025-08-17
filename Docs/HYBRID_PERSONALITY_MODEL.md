# Hybrid Personality Model (Encorely)

Encorely replaces MBTI with a Big Five (OCEAN) profile and maps it to UI personas for stable UX while enabling fine‑grained recommendation tuning.

## Data model
- BigFiveProfile: openness, conscientiousness, extraversion, agreeableness, neuroticism (0.0–1.0)
- PersonalityType (UI personas): analyzer, explorer, planner, creative, balanced (+ legacy: curator, enthusiast, social, ambient, neutral)
- AudioPreferenceWeights: energy, complexity, tempo, acousticness (0.0–1.0)

## Mapping
- openness>0.7 && extraversion>0.5 → explorer
- conscientiousness>0.7 → planner
- openness>0.65 && agreeableness>0.55 → creative
- near‑balanced traits → balanced
- otherwise → analyzer

## Weights (used by RecommendationEngine)
- energy = 0.3*extraversion + 0.15*(1−neuroticism) + 0.1
- complexity = 0.35*openness + 0.1*(1−conscientiousness)
- tempo = 0.25*extraversion + 0.2*openness
- acousticness = 0.25*agreeableness + 0.15*conscientiousness

Weights are blended with mood scoring: score = 0.7*base_mood + 0.3*(weighted features).
Complexity is approximated as 0.6*(1−danceability)+0.4*instrumentalness.

## Usage
- Set/update via RecommendationEngine.updateBigFiveProfile(_:) to tune ranking; UI buckets stay stable via mappedPersonalityType.

## Privacy
- All inference is on‑device. No raw audio or camera data leaves the device by default.
