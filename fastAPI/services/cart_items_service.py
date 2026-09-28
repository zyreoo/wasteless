from fastapi import HTTPException
from repositories.cart_items_repository import CartItemsRepository


class CartItemsService:
    def __init__(self):
        self.repository = CartItemsRepository()

    def get_all(self):
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch cart items")
