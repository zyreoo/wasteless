from fastapi import HTTPException
from repositories.order_items_repository import OrderItemsRepository


class OrderItemsService:
    def __init__(self):
        self.repository = OrderItemsRepository()

    def get_all(self):
        # TODO: filtreaza dupa comanda/utilizatorul curent odata ce este implementata
        # autentificarea in proiect - altfel oricine vede itemii oricarei comenzi
        try:
            return self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch order items")
