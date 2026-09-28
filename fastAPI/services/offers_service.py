from fastapi import HTTPException
from repositories.offers_repository import OffersRepository


class OffersService:
    def __init__(self):
        self.repository = OffersRepository()

    def get_all(self):
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch offers")
