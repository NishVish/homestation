from django.shortcuts import render
from django.utils import timezone
import socket
import platform

def index(request):
   
    return render(request, 'agent/index.html')

