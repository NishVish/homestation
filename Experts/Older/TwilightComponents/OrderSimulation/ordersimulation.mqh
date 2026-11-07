
struct orderx {

    int id;
    string type;
    int orderType;
    string symbol;
    datetime entryTime;
    datetime exitTime;
    double entryPrice = 0;
    bool target1Hit = false;
    double targetPrice1 = 0;

    bool target2Hit = false;
    double targetPrice2 = 0;

    bool target3Hit = false;
    double targetPrice3 = 0;

    bool target4Hit = false;
    double targetPrice4 = 0;

    bool target5Hit = false;
    double targetPrice5 = 0;
    bool loss1Hit = false;
    bool loss2Hit = false;
    bool loss3Hit = false;
    bool loss4Hit = false;
    bool loss5Hit = false;
    bool status = false;

}


struct order {

    int id;
    string type;
    bool target1Hit = false;
    double targetPrice1 = 0;
    bool status = false;

}

struct orderlist {

    order orderlistt[];
    
}



initialize order and set its target prices



crossvalidate with curretprice and update the order
if orderstatus is false then update the parameter


10pip 20pips target