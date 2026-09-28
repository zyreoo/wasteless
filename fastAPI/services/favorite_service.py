from fastapi import HTTPException
from repositories.favorite_repository import FavoriteRepository


class FavoriteService:
    def __init__(self):
        self.repository = FavoriteRepository()

    def get_all(self):
        # TODO: filtreaza dupa utilizatorul curent (WHERE user_id = ...) odata ce
        # este implementata autentificarea in proiect - altfel oricine vede favoritele oricui
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch favorite")
