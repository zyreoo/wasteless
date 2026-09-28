from db.supabase_client import supabase


class UserRepository:
    # nu extinde BaseRepository: aici nu interogam un tabel, ci API-ul de admin
    # al Supabase Auth (supabase.auth.admin), care are alta forma de raspuns

    def find_all(self):
        response = supabase.auth.admin.list_users()
        return response
