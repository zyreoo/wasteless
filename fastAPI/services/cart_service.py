from fastapi import HTTPException
from repositories.cart_repository import CartRepository


class CartService:
    def __init__(self):
        self.repository = CartRepository()

    def get_all(self):
        # TODO: filtreaza dupa utilizatorul curent (WHERE user_id = ...) odata ce
        # este implementata autentificarea in proiect - altfel oricine vede orice cos
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch cart")
