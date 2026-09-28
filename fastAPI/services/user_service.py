from fastapi import HTTPException
from repositories.user_repository import UserRepository


class UserService:
    # TODO: acest endpoint listeaza toti utilizatorii din proiect folosind cheia de admin
    # (SUPABASE_SECRET_KEY) - ar trebui protejat, accesibil doar pentru un admin autentificat,
    # nu public, odata ce exista autentificare/autorizare in proiect

    def __init__(self):
        self.repository = UserRepository()

    def get_all(self):
        try:
            users = self.repository.find_all()
        except Exception:
            raise HTTPException(status_code=500, detail="Could not fetch users")

        # nu expunem obiectul brut de auth (contine telefon, metadata, provideri de login etc.)
        # ci doar campurile minime necesare clientului -> asta e Projection/DTO-ul mentionat in review
        return [
            {
                "id": user.id,
                "email": user.email,
                "created_at": user.created_at,
            }
            for user in users
        ]
