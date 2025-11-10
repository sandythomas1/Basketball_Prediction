import requests 
import os
from dotenv import load_dotenv
import time 

load_dotenv()

api_key = os.getenv('balldontlie_api_key')
headers = {
    'Authorization': api_key
}

def fetch_all_pages(url, params, max_retries=3):
    curr_request = 0
    results = []

    # First request with retry logic
    retry_count = 0
    while retry_count < max_retries:
        response = requests.get(url, params=params, headers=headers)
        
        if response.status_code == 429:
            wait_time = 60 * (retry_count + 1)  # Wait 60, 120, 180 seconds
            print(f"Rate limited. Waiting {wait_time} seconds before retry {retry_count + 1}/{max_retries}...")
            time.sleep(wait_time)
            retry_count += 1
            continue
        elif response.status_code != 200:
            print(f"Error: API returned status code {response.status_code}")
            print(f"Response: {response.text}")
            return results
        else:
            break
    
    if retry_count >= max_retries:
        print(f"Failed after {max_retries} retries. Please wait longer before trying again.")
        return results
    
    data = response.json()
    
    # Check if response has expected structure
    if 'data' not in data:
        print(f"Error: Response missing 'data' key")
        print(f"Response: {data}")
        return results
    
    results.extend(data['data'])
    
    # Check if 'meta' exists (some endpoints might not have pagination)
    if 'meta' not in data:
        print(f"Warning: No 'meta' key in response. Returning single page of results.")
        return results
    
    next_cursor = data['meta'].get('next_cursor')

    while next_cursor is not None:
        curr_request += 1 
        time.sleep(1)  # Rate limiting delay between requests
        
        # 1. Update params with the new cursor
        params['cursor'] = next_cursor
        
        # 2. Make the request for the *next* page with retry logic
        retry_count = 0
        while retry_count < max_retries:
            response = requests.get(url, params=params, headers=headers)
            
            if response.status_code == 429:
                wait_time = 60 * (retry_count + 1)
                print(f"Rate limited on request {curr_request}. Waiting {wait_time} seconds...")
                time.sleep(wait_time)
                retry_count += 1
                continue
            elif response.status_code != 200:
                print(f"Error on request {curr_request}: API returned status code {response.status_code}")
                print(f"Response: {response.text}")
                return results
            else:
                break
        
        if retry_count >= max_retries:
            print(f"Failed after {max_retries} retries on request {curr_request}")
            return results
        
        data = response.json()
        
        # Check for expected structure
        if 'data' not in data or 'meta' not in data:
            print(f"Error on request {curr_request}: Invalid response structure")
            print(f"Response: {data}")
            break
        
        # 3. Add the new data
        results.extend(data['data'])
        
        # 4. Get the *next* cursor for the *next* loop
        next_cursor = data['meta'].get('next_cursor')

        # Debugging
        print(f"Request {curr_request}: Found cursor {next_cursor}, fetched {len(results)} total items")

    return results

if __name__ == "__main__":
    print("=" * 60)
    print("Basketball Data Collection")
    print("=" * 60)
    
    print("\n[1/3] Fetching players...")
    all_players = fetch_all_pages('https://api.balldontlie.io/v1/players', {'per_page': 100})
    if len(all_players) > 0:
        print(f"✓ Fetched {len(all_players)} players\n")
    else:
        print(f"✗ Failed to fetch players\n")
    
    print("[2/3] Fetching teams...")
    all_teams = fetch_all_pages('https://api.balldontlie.io/v1/teams', {'per_page': 100})
    if len(all_teams) > 0:
        print(f"✓ Fetched {len(all_teams)} teams\n")
    else:
        print(f"✗ Failed to fetch teams\n")
    
    print("[3/3] Fetching games...")
    all_games = fetch_all_pages('https://api.balldontlie.io/v1/games', {'per_page': 100})
    if len(all_games) > 0:
        print(f"✓ Fetched {len(all_games)} games\n")
    else:
        print(f"✗ Failed to fetch games\n")
    
    print("=" * 60)
    print(f"Summary: {len(all_players)} players, {len(all_teams)} teams, {len(all_games)} games")
    print("=" * 60)


