# sqlconnection.py

import mysql.connector
from mysql.connector import Error

def get_connection():
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",          # set your password if any
            database="marketdata"
        )

        if connection.is_connected():
            print("Connected to MySQL database: marketdata")
            return connection

    except Error as e:
        print(f"Error while connecting to MySQL: {e}")
        return None


def close_connection(connection):
    if connection and connection.is_connected():
        connection.close()
        print("MySQL connection closed")