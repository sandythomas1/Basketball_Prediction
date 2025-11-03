import requests 

def fetch_all_pages(url, params):
    curr_request = 1
    results = []

    url = 'https://api.balldontlie.io/v1/'
    response = requests.get(url, params=params)
    data =response.json()
    results.extend(data['data'])
    next_cursor = data['meta'].get('next_cursor')

    while next_cursor is not None:
        curr_request += 1 
        
        # 1. Update params with the new cursor
        params['cursor'] = next_cursor
        
        # 2. Make the request for the *next* page
        response = requests.get(url, params=params)
        data = response.json()
        
        # 3. Add the new data
        results.extend(data['data'])
        
        # 4. Get the *next* cursor for the *next* loop
        next_cursor = data['meta'].get('next_cursor')

        # Debugging
        print(f"Request {curr_request}: Found cursor {next_cursor}")

    return results
