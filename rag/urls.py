from rag.views import chat_page
from django.urls import path
from .views import ask, train, chat

urlpatterns = [
    path("ask/", ask),
    path("train/", train),
    path("chat/", chat),   
    path("chatpage/", chat_page),

]