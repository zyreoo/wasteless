#aici tinem conexiunea cu supabase, sa nu o cream de fiecare data cand facem un request



import os       
from dotenv import load_dotenv
from supabase import create_client, Client, ClientOptions


load_dotenv()


url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SECRET_KEY") #aici luam url-ul si cheia din variabilele de mediu, astfel incat sa nu fie hardcodate in codul sursa


options = ClientOptions(
    # schema="tebelenoi"
    schema="public" #avem nevoisi de schema auth la varianta finala
) #aici setam schema default pentru supabase, astfel incat sa nu fie nevoie sa o specificam de fiecare data cand facem un request


supabase: Client = create_client(
    url, key, options=options 
    ) #aici cream conexiunea cu supabase, folosind url-ul si cheia din variabilele de mediu








