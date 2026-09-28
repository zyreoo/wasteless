from fastapi import HTTPException
from repositories.loyalty_points_repository import LoyaltyPointsRepository


class LoyaltyPointsService:
    def __init__(self):
        self.repository = LoyaltyPointsRepository()

    def get_all(self):
        # TODO: filtreaza dupa utilizatorul curent (WHERE user_id = ...) odata ce
        # este implementata autentificarea in proiect - altfel oricine vede punctele oricui
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch loyalty points")
