import random
from typing import List, Dict, Tuple
from collections import defaultdict
from .predictor import Predictor
from .feature_builder import FeatureBuilder

class BracketSimulator:
    """
    Monte Carlo simulator for the 64-team March Madness bracket.
    """
    
    def __init__(self, predictor: Predictor, feature_builder: FeatureBuilder):
        self.predictor = predictor
        self.feature_builder = feature_builder
        
    def _build_probability_matrix(self, team_ids: List[int], game_date: str) -> Dict[Tuple[int, int], float]:
        """
        Pre-compute win probabilities for every possible matchup among the 64 teams.
        Returns a dict mapping (team_a, team_b) -> probability team_a wins.
        """
        prob_matrix = {}
        for i in range(len(team_ids)):
            for j in range(i + 1, len(team_ids)):
                team_a = team_ids[i]
                team_b = team_ids[j]
                
                # Predict team_a as home. In a real neutral site we'd want to remove HCA.
                # For now, we accept the slight bias or we can average A@B and B@A.
                # Averaging removes the home court bias effectively.
                result_ab = self.predictor.predict_game(team_a, team_b, game_date, self.feature_builder)
                result_ba = self.predictor.predict_game(team_b, team_a, game_date, self.feature_builder)
                
                # prob_a_wins = (A beats B at home + A beats B away) / 2
                prob_a_wins = (result_ab["prob_home_win"] + result_ba["prob_away_win"]) / 2.0
                
                prob_matrix[(team_a, team_b)] = prob_a_wins
                prob_matrix[(team_b, team_a)] = 1.0 - prob_a_wins
                
        return prob_matrix

    def simulate(self, team_ids: List[int], game_date: str, iterations: int = 1000) -> Dict[int, Dict[str, float]]:
        """
        Run Monte Carlo simulation on the 64-team bracket.
        Returns the probability of each team reaching each round.
        
        Rounds tracked: R32, Sweet16, Elite8, FinalFour, Championship, Winner
        """
        if len(team_ids) != 64:
            raise ValueError(f"Expected exactly 64 teams, got {len(team_ids)}")
            
        # 1. Precompute probabilities to make simulations extremely fast
        prob_matrix = self._build_probability_matrix(team_ids, game_date)
        
        # 2. Track results
        # Mapping: team_id -> { "R32": count, "S16": count, "E8": count, "F4": count, "NC": count, "W": count }
        results = {team: {
            "R32": 0, "S16": 0, "E8": 0, "F4": 0, "NC": 0, "W": 0
        } for team in team_ids}
        
        # 3. Run iterations
        for _ in range(iterations):
            current_round = list(team_ids)
            
            # Round 1 -> R32
            r32 = self._play_round(current_round, prob_matrix)
            for t in r32: results[t]["R32"] += 1
            
            # R32 -> S16
            s16 = self._play_round(r32, prob_matrix)
            for t in s16: results[t]["S16"] += 1
            
            # S16 -> E8
            e8 = self._play_round(s16, prob_matrix)
            for t in e8: results[t]["E8"] += 1
            
            # E8 -> F4
            f4 = self._play_round(e8, prob_matrix)
            for t in f4: results[t]["F4"] += 1
            
            # F4 -> Championship
            nc = self._play_round(f4, prob_matrix)
            for t in nc: results[t]["NC"] += 1
            
            # Championship -> Winner
            winner = self._play_round(nc, prob_matrix)
            for t in winner: results[t]["W"] += 1
            
        # 4. Normalize to probabilities
        final_probs = {}
        for team, counts in results.items():
            final_probs[team] = {
                round_name: count / iterations
                for round_name, count in counts.items()
            }
            
        return final_probs
        
    def _play_round(self, teams: List[int], prob_matrix: Dict[Tuple[int, int], float]) -> List[int]:
        """Play a single elimination round for the given list of teams."""
        winners = []
        # Step by 2
        for i in range(0, len(teams), 2):
            team_a = teams[i]
            team_b = teams[i+1]
            
            prob_a_wins = prob_matrix[(team_a, team_b)]
            
            if random.random() < prob_a_wins:
                winners.append(team_a)
            else:
                winners.append(team_b)
                
        return winners
