from fastapi import HTTPException
from repositories.offer_items_repository import OfferItemsRepository


class OfferItemsService:
    def __init__(self):
        self.repository = OfferItemsRepository()

    def get_all(self):
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch offer items")
