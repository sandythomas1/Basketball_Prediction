from pathlib import Path
import sys

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from core import StateManager, FeatureBuilder, Predictor, ConfidenceScorer

# Load state
state_dir = Path("state")
state_manager = StateManager(state_dir)
elo_tracker, stats_tracker = state_manager.load()

# Create components
feature_builder = FeatureBuilder(elo_tracker, stats_tracker)
confidence_scorer = ConfidenceScorer(stats_tracker)

# Load predictor with confidence scorer
predictor = Predictor(
    model_path=Path("models/xgb_v2_modern.json"),
    calibrator_path=Path("models/calibrator.pkl"),
    confidence_scorer=confidence_scorer
)

# Make a prediction - Wizards (27) vs Bucks (15) like in your screenshot
result = predictor.predict_game(
    home_id=27,  # Wizards
    away_id=15,  # Bucks
    game_date="2026-01-29",
    feature_builder=feature_builder
)

print("\n" + "="*60)
print("PREDICTION RESULTS")
print("="*60)
print(f"Matchup: Wizards vs Bucks")
print(f"Home Win Probability: {result['prob_home_win']:.1%}")
print(f"Confidence Tier: {result['confidence_tier']}")

print("\n" + "="*60)
print("NEW CONFIDENCE METRICS")
print("="*60)
print(f"Confidence Score: {result.get('confidence_score', 'N/A')}/100")
print(f"Qualifier: {result.get('confidence_qualifier', 'N/A')}")

if 'confidence_factors' in result:
    print("\nFactor Breakdown:")
    for factor, value in result['confidence_factors'].items():
        max_vals = {
            'consensus_agreement': 25,
            'feature_alignment': 25,
            'form_stability': 20,
            'schedule_context': 15,
            'matchup_history': 15
        }
        max_val = max_vals.get(factor, 25)
        bar_length = int((value / max_val) * 30)
        bar = '█' * bar_length + '░' * (30 - bar_length)
        print(f"  {factor:25s}: {value:5.1f}/{max_val:2d} {bar}")
else:
    print("\n No confidence factors found!")
    print("Make sure the predictor was initialized with confidence_scorer")

print("\n" + "="*60)