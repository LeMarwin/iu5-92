module util;

import std.datetime;
import std.typecons;
import std.random;
import std.math;
import core.thread;

Duration exp(Duration lambdaInv)
{
    return dur!"msecs"(cast(ulong)(-log(uniform!"[]"(0.0, 1.0)) * cast(double)lambdaInv.total!"msecs"));
}

Duration waitExp(Duration dur)
{
    auto time = dur.exp;
    Thread.sleep(time);
    return time;
}

Tuple!(double, double, double) mean(Tuple!(double, double, double)[] arr)
{
    Tuple!(double, double, double) summ = tuple(0, 0, 0);
    foreach(v; arr)
    {
        summ[0] += v[0];
        summ[1] += v[1];
        summ[2] += v[2];
    }
    summ[0] /= arr.length;
    summ[1] /= arr.length;
    summ[2] /= arr.length;
    
    return summ;
}

double mean(double[] arr)
{
    double temp = 0.0;
    foreach(val; arr) temp += val;
    return temp / arr.length;
}

TickDuration minStamp(T)(T[string] tics)
{
    TickDuration res = tics[tics.keys[0]].startStamp;
    foreach(k;tics.keys)
    {
        if(res>tics[k].startStamp)
            res=tics[k].startStamp;
    }
    return res;
}