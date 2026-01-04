"""
Example script demonstrating how to use the core prediction module.

Prerequisites:
1. Run bootstrap_state.py to create state/elo.json and state/stats.json
2. Run xgb_boost_model.py to create models/calibrator.pkl
"""

from pathlib import Path
from core import TeamMapper, EloTracker, StatsTracker, FeatureBuilder, Predictor


def main():
    # ==========================
    # Setup paths
    # ==========================
    PROJECT_ROOT = Path(__file__).parent.parent
    
    STATE_DIR = PROJECT_ROOT / "state"
    MODELS_DIR = PROJECT_ROOT / "models"
    
    ELO_STATE_PATH = STATE_DIR / "elo.json"
    STATS_STATE_PATH = STATE_DIR / "stats.json"
    MODEL_PATH = MODELS_DIR / "xgb_v2_modern.json"
    CALIBRATOR_PATH = MODELS_DIR / "calibrator.pkl"
    
    # ==========================
    # Initialize components
    # ==========================
    print("Loading components...")
    
    # Team mapper for name -> ID conversion
    mapper = TeamMapper()
    
    # Load state from files (created by bootstrap_state.py)
    elo_tracker = EloTracker.from_file(ELO_STATE_PATH)
    stats_tracker = StatsTracker.from_file(STATS_STATE_PATH)
    
    # Feature builder combines trackers
    feature_builder = FeatureBuilder(elo_tracker, stats_tracker)
    
    # Predictor loads model + calibrator
    predictor = Predictor(MODEL_PATH, CALIBRATOR_PATH)
    
    print(f"  {elo_tracker}")
    print(f"  {stats_tracker}")
    print(f"  {predictor}")
    
    # ==========================
    # Example: Predict a single game
    # ==========================
    print("\n" + "=" * 50)
    print("Example: Warriors vs Thunder")
    print("=" * 50)
    
    # Convert team names to IDs
    home_team = "Golden State Warriors"
    away_team = "Oklahoma City Thunder"
    game_date = "2026-01-02"
    
    home_id = mapper.get_team_id(home_team)
    away_id = mapper.get_team_id(away_team)
    
    print(f"\n{home_team} (ID: {home_id}) vs {away_team} (ID: {away_id})")
    print(f"Game date: {game_date}")
    
    # Check current Elo ratings
    print(f"\nCurrent Elo ratings:")
    print(f"  {home_team}: {elo_tracker.get_elo(home_id):.1f}")
    print(f"  {away_team}: {elo_tracker.get_elo(away_id):.1f}")
    
    # Get prediction
    result = predictor.predict_game(home_id, away_id, game_date, feature_builder)
    
    print(f"\nPrediction:")
    print(f"  Home win probability: {result['prob_home_win']:.1%}")
    print(f"  Away win probability: {result['prob_away_win']:.1%}")
    print(f"  Confidence tier: {result['confidence_tier']}")
    print(f"  Calibrated: {result['is_calibrated']}")
    
    # ==========================
    # Example: Inspect features
    # ==========================
    print("\n" + "=" * 50)
    print("Feature breakdown")
    print("=" * 50)
    
    features_dict = feature_builder.build_features_dict(home_id, away_id, game_date)
    
    print("\nElo features:")
    for key in ["elo_home", "elo_away", "elo_diff", "elo_prob"]:
        print(f"  {key}: {features_dict[key]:.3f}")
    
    print("\nRolling stats (home):")
    for key in ["pf_roll_home", "pa_roll_home", "win_roll_home", "margin_roll_home"]:
        print(f"  {key}: {features_dict[key]:.3f}")
    
    print("\nRest features:")
    for key in ["home_rest_days", "away_rest_days", "home_b2b", "away_b2b", "rest_diff"]:
        print(f"  {key}: {features_dict[key]:.1f}")
    
    # ==========================
    # Example: Batch predictions
    # ==========================
    print("\n" + "=" * 50)
    print("Batch prediction example")
    print("=" * 50)
    
    games = [
        {"home_id": mapper.get_team_id("Golden State Warriors"), 
         "away_id": mapper.get_team_id("Phoenix Suns"), 
         "game_date": "2026-01-03"},
        {"home_id": mapper.get_team_id("Miami Heat"), 
         "away_id": mapper.get_team_id("Brooklyn Nets"), 
         "game_date": "2026-01-03"},
    ]
    
    results = predictor.predict_batch(games, feature_builder)
    
    for game, result in zip(games, results):
        home_name = mapper.get_team_name(game["home_id"])
        away_name = mapper.get_team_name(game["away_id"])
        print(f"\n{home_name} vs {away_name}")
        print(f"  Home win: {result['prob_home_win']:.1%} ({result['confidence_tier']})")


if __name__ == "__main__":
    main()

