from django.shortcuts import render
from django.utils import timezone
import socket
import platform

def index(request):
    # Retrieve some basic system information
    try:
        host_name = socket.gethostname()
        host_ip = socket.gethostbyname(host_name)
    except Exception:
        host_name = "homestation-server"
        host_ip = "192.168.1.100"

    context = {
        'server_info': {
            'hostname': host_name,
            'ip': host_ip,
            'os': f"{platform.system()} {platform.release()}",
            'timezone': timezone.get_current_timezone_name(),
        },
        'system_status': {
            'cpu_usage': 28,  # mock percentage
            'ram_usage': 42,  # mock percentage
            'storage_free': '1.2 TB / 2.0 TB',
            'cpu_temp': 45.2,  # in Celsius
            'uptime': '4 days, 12 hours, 31 minutes',
        },
        'weather': {
            'temp': 22,
            'condition': 'Clear Sky',
            'humidity': 54,
            'wind': '8 km/h',
            'location': 'Home Base',
        },
        'devices': [
            {'name': 'Living Room Smart TV', 'ip': '192.168.1.101', 'status': 'online', 'type': 'Entertainment'},
            {'name': 'Kitchen Smart Fridge', 'ip': '192.168.1.102', 'status': 'online', 'type': 'Appliance'},
            {'name': 'Bedroom AC Controller', 'ip': '192.168.1.115', 'status': 'offline', 'type': 'Climate'},
            {'name': 'HomeAssistant Hub', 'ip': '192.168.1.200', 'status': 'online', 'type': 'Server'},
            {'name': 'Front Door Smart Lock', 'ip': '192.168.1.105', 'status': 'online', 'type': 'Security'},
        ],
        'recent_logs': [
            {'time': '23:44', 'tag': 'SYSTEM', 'message': 'Scheduled backup completed successfully.'},
            {'time': '22:15', 'tag': 'SECURITY', 'message': 'Front Door Smart Lock unlocked by User Admin.'},
            {'time': '20:30', 'tag': 'CLIMATE', 'message': 'Living Room AC turned off (target reached).'},
            {'time': '18:12', 'tag': 'NETWORK', 'message': 'New device connected to guest network.'},
        ]
    }
    return render(request, 'dashboard/index.html', context)

