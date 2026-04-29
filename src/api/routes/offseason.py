from fastapi import APIRouter, HTTPException
import httpx
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/nba/offseason", tags=["Offseason"])

# Static mock data for Draft
MOCK_DRAFT_PROSPECTS = [
    {"id": 1, "name": "Cooper Flagg", "position": "F", "school": "Duke", "projected_pick": "1st Overall", "strengths": "Defense, Versatility, IQ", "image_url": "https://a.espncdn.com/i/headshots/recruiting/ncb/players/full/246416.png"},
    {"id": 2, "name": "Ace Bailey", "position": "F", "school": "Rutgers", "projected_pick": "Top 3", "strengths": "Shot Creation, Athleticism", "image_url": "https://a.espncdn.com/i/headshots/recruiting/ncb/players/full/248386.png"},
    {"id": 3, "name": "Dylan Harper", "position": "G", "school": "Rutgers", "projected_pick": "Top 5", "strengths": "Playmaking, Scoring", "image_url": "https://a.espncdn.com/i/headshots/recruiting/ncb/players/full/248398.png"},
    {"id": 4, "name": "V.J. Edgecombe", "position": "G", "school": "Baylor", "projected_pick": "Top 5", "strengths": "Slashing, Explosiveness", "image_url": "https://a.espncdn.com/i/headshots/recruiting/ncb/players/full/248405.png"},
    {"id": 5, "name": "Tre Johnson", "position": "G", "school": "Texas", "projected_pick": "Top 10", "strengths": "Shooting, Pure Scoring", "image_url": "https://a.espncdn.com/i/headshots/recruiting/ncb/players/full/246445.png"},
    {"id": 6, "name": "Khaman Maluach", "position": "C", "school": "Duke", "projected_pick": "Top 10", "strengths": "Size, Rim Protection", "image_url": "https://a.espncdn.com/i/headshots/recruiting/ncb/players/full/255536.png"},
    {"id": 7, "name": "Nolan Traore", "position": "G", "school": "France", "projected_pick": "Lottery", "strengths": "Pick & Roll, Quickness", "image_url": "https://a.espncdn.com/i/headshots/nba/players/full/1234567.png"},
    {"id": 8, "name": "Drake Powell", "position": "F", "school": "UNC", "projected_pick": "Lottery", "strengths": "Two-way Potential, Wing Defense", "image_url": "https://a.espncdn.com/i/headshots/recruiting/ncb/players/full/246422.png"},
    {"id": 9, "name": "Hugo Gonzalez", "position": "F", "school": "Real Madrid", "projected_pick": "Lottery", "strengths": "Motor, Defensive Versatility", "image_url": "https://a.espncdn.com/i/headshots/nba/players/full/1234568.png"},
    {"id": 10, "name": "Ian Jackson", "position": "G", "school": "UNC", "projected_pick": "Mid 1st Round", "strengths": "Scoring, Energy", "image_url": "https://a.espncdn.com/i/headshots/recruiting/ncb/players/full/246419.png"},
]

# Static mock data for Free Agents
MOCK_FREE_AGENTS = [
    {"id": 1, "name": "Luka Doncic", "position": "PG", "previous_team": "Dallas Mavericks", "status": "Player Option", "projected_contract": "$346M / 5 yrs"},
    {"id": 2, "name": "Shai Gilgeous-Alexander", "position": "PG", "previous_team": "Oklahoma City Thunder", "status": "Extension Eligible", "projected_contract": "$294M / 4 yrs"},
    {"id": 3, "name": "Giannis Antetokounmpo", "position": "PF", "previous_team": "Milwaukee Bucks", "status": "Player Option", "projected_contract": "$300M / 5 yrs"},
    {"id": 4, "name": "De'Aaron Fox", "position": "PG", "previous_team": "Sacramento Kings", "status": "Unrestricted", "projected_contract": "$180M / 4 yrs"},
    {"id": 5, "name": "Donovan Mitchell", "position": "SG", "previous_team": "Cleveland Cavaliers", "status": "Player Option", "projected_contract": "$200M / 4 yrs"},
    {"id": 6, "name": "Jimmy Butler", "position": "SF", "previous_team": "Miami Heat", "status": "Unrestricted", "projected_contract": "$100M / 2 yrs"},
    {"id": 7, "name": "Brandon Ingram", "position": "SF", "previous_team": "New Orleans Pelicans", "status": "Unrestricted", "projected_contract": "$160M / 4 yrs"},
    {"id": 8, "name": "Kyrie Irving", "position": "PG", "previous_team": "Dallas Mavericks", "status": "Player Option", "projected_contract": "$120M / 3 yrs"},
    {"id": 9, "name": "Jaren Jackson Jr.", "position": "PF", "previous_team": "Memphis Grizzlies", "status": "Unrestricted", "projected_contract": "$150M / 4 yrs"},
    {"id": 10, "name": "Mikal Bridges", "position": "SF", "previous_team": "New York Knicks", "status": "Unrestricted", "projected_contract": "$140M / 4 yrs"},
]

@router.get("/news")
async def get_offseason_news():
    """Fetch the latest NBA news from the ESPN API."""
    url = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/news"
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=10.0)
            if response.status_code == 200:
                data = response.json()
                articles = data.get("articles", [])
                
                # Format to a cleaner payload
                clean_articles = []
                for article in articles:
                    images = article.get("images", [])
                    image_url = images[0].get("url") if images else None
                    
                    clean_articles.append({
                        "headline": article.get("headline"),
                        "description": article.get("description"),
                        "published": article.get("published"),
                        "link": article.get("links", {}).get("web", {}).get("href"),
                        "image_url": image_url
                    })
                    
                return {"status": "success", "news": clean_articles}
            else:
                raise HTTPException(status_code=response.status_code, detail="Failed to fetch ESPN news")
    except Exception as e:
        logger.error(f"Error fetching news: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/draft")
async def get_draft_prospects():
    """Returns a curated list of top draft prospects."""
    return {"status": "success", "prospects": MOCK_DRAFT_PROSPECTS}

@router.get("/free-agents")
async def get_free_agents():
    """Returns a curated list of top free agents."""
    return {"status": "success", "free_agents": MOCK_FREE_AGENTS}
