import pandas as pd

# from sqlconnection import get_connection, close_connection

# conn = get_connection()

def loadsqltodf():
    query = """
    SELECT *
    FROM multitimeframe_snapshot_features
    """
    
    df = pd.read_sql_query(query, conn)
    
    close_connection(conn)
    
    print(df.shape)
    return df