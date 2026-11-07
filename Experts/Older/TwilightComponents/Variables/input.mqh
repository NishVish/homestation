
input string FileName = "H4_Last50.csv";
input int CandleCount = 50;

datetime lastBarTime = 0;
string tradingDirection = "Neutral";

// put helper here
bool IsValid(double price)
{
    return(price > - 1e10 && price < 1e10);
}



input bool printon = true;

// Input
int candletoworkwith = 100;
