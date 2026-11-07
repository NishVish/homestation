void makeorders()
{
    for(int i = 10; i <= 60; i += 10)
    {
        order(true, 0.01, 10, i);
        order(false, 0.01, 10, i);
    }
}