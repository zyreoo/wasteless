from fastapi import FastAPI
from routes.cart import router as cart_router
from routes.favorite import router as favorite_router
from routes.settings import router as settings_router
from routes.offers import router as offers_router
from routes.order import router as order_router

#!!!folosite doar in schema public:
from routes.cart_items import router as cart_items_router
from routes.location_type import router as location_type_router
from routes.locations import router as locations_router
from routes.loyalty_points import router as loyalty_points_router
from routes.merchants import router as merchants_router
from routes.offer_items import router as offer_items_router
from routes.order_items import router as order_items_router
from routes.order_status import router as order_status_router
from routes.order_type import router as order_type_router
from routes.product import router as product_router
from routes.users import router as users_router

app = FastAPI()
app.include_router(cart_router)
app.include_router(favorite_router)
app.include_router(settings_router)
app.include_router(offers_router)
app.include_router(order_router)
app.include_router(users_router)

#!!!folosite doar in schema public:
app.include_router(cart_items_router)
app.include_router(location_type_router)
app.include_router(locations_router)
app.include_router(loyalty_points_router)
app.include_router(merchants_router)
app.include_router(offer_items_router)
app.include_router(order_items_router)
app.include_router(order_status_router)
app.include_router(order_type_router)
app.include_router(product_router)


#   new routes:
# settings
# offers
# order
# cart_items
# location_type
# locations
# loyalty_points
# merchants
# offer_items
# order_items
# order_status
# order_type
# products