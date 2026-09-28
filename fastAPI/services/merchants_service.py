from fastapi import HTTPException
from repositories.merchants_repository import MerchantsRepository


class MerchantsService:
    def __init__(self):
        self.repository = MerchantsRepository()

    def get_all(self):
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch merchants")
