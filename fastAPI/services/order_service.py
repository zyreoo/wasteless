from fastapi import HTTPException
from repositories.order_repository import OrderRepository


class OrderService:
    def __init__(self):
        self.repository = OrderRepository()

    def get_all(self):
        # TODO: filtreaza dupa utilizatorul curent (WHERE user_id = ...) odata ce
        # este implementata autentificarea in proiect - altfel oricine vede comenzile oricui
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch order")
