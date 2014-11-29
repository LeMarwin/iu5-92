module sim;

import std.algorithm;
import std.datetime;
import std.concurrency;
import std.container.dlist;
import std.typecons;
import std.random;
import std.conv;
import core.thread;

import data;
import util;

struct Query
{
    size_t workstation;
    size_t server;
    
    TickDuration startStamp;
}

struct Response
{
    size_t workstation;
    
    TickDuration startStamp;
}

struct SubQuery
{
    string id;
    size_t workstation;
    size_t server;
    TickDuration startStamp;
}

void workstationProcess(Duration To, Duration Tp, size_t workstationId, size_t serversCount)
{
    scope(failure) {std.stdio.writeln("workWasted!");}
    Thread.getThis.isDaemon = true;
    Tid cableProcessTid = receiveOnly!Tid;
    
    Duration totalLifetime = 0.dur!"msecs";
    size_t totalResponses = 0;
    auto startStamp = Clock.currAppTick;
    Duration loadTime = 0.dur!"msecs";
    Duration userLoadTime = 0.dur!"msecs";
    
    void postResponse(Response r)
    {
        loadTime += waitExp(To);
        totalLifetime += Clock.currAppTick - r.startStamp;
        totalResponses += 1; 
    }
    
    void genQuery()
    {
       auto query = Query(workstationId, uniform(0, serversCount), Clock.currAppTick);
       auto t = waitExp(Tp.exp);
       loadTime += t;
       userLoadTime += t;
       cableProcessTid.send(query);
    }
    
    genQuery();
    
    
    while(true) {
        receive(
            (Response r) {
                postResponse(r);
                genQuery();
            },
            (Tid asker) {
                double reactionTime = totalLifetime.total!"msecs" / cast(double)totalResponses;
                auto totalTime = cast(double)(cast(Duration)(Clock.currAppTick - startStamp)).total!"msecs";
                double loadFactor = loadTime.total!"msecs" / totalTime;
                double userLoadFactor = userLoadTime.total!"msecs" / totalTime;
                asker.send(reactionTime, loadFactor, userLoadFactor);
            }
        );
    }
}

void cableProcess(Duration tk, const Tid[] workstations, const Tid[] servers)
{
    scope(failure) {std.stdio.writeln("cableWasted!");}
    Thread.getThis.isDaemon = true;
    auto startStamp = Clock.currAppTick;
    Duration loadTime = 0.dur!"msecs";
    
    while(true) {
        receive(
            (Response r) {
                loadTime += waitExp(tk);
                (cast()workstations[r.workstation]).send(r);
            },
            (Query q) {
                loadTime += waitExp(tk);
                (cast()servers[q.server]).send(q);
            },
            (Tid asker) {
                auto totalTime = cast(double)(cast(Duration)(Clock.currAppTick - startStamp)).total!"msecs";
                asker.send(loadTime.total!"msecs" / totalTime);
            }
        );
    }
}

void serverProcess(Input input)
{
    try{
    scope(failure) {std.stdio.writeln("serverWasted!");}
    Thread.getThis.isDaemon = true;
    //Tid[] cpuIds = cast(Tid[])receiveOnly!(shared Tid[]); 
    Tid[] cpuIds = [];
    try{
        while (true) {
            cpuIds ~= receiveOnly!Tid;
        }
    }
    catch(Exception e){}
    Tid cableProcessId = receiveOnly!Tid;
    SubQuery[string] running;
    int num = 0;
    TickDuration startStamp = Clock.currAppTick;
    TickDuration subStartStamp;
    Duration loadTime = 0.dur!"msecs";
    
    while(true) {
        receive(
            (Query q) {
                if(running.length==0)
                    subStartStamp = Clock.currAppTick;
                string s = num.to!string;
                num++;
                running[s] = SubQuery(s, q.workstation,q.server,Clock.currAppTick);
                //std.stdio.writeln(running.length);
                cpuIds[uniform(0,input.cpusCount)].send(running[s]);
            },
            (Tid asker) {
                loadTime+=cast(Duration)(Clock.currAppTick-subStartStamp);
                auto totalTime = cast(double)(cast(Duration)(Clock.currAppTick - startStamp)).total!"msecs";
                asker.send(loadTime.total!"msecs" / totalTime);
            },
            (SubQuery sq){
                TickDuration diff = sq.startStamp - subStartStamp;
                cableProcessId.send(Response(sq.workstation,running[sq.id].startStamp));
                running.remove(sq.id);
                if(running.length==0)
                {
                    std.stdio.writeln("lol-",num);
                    loadTime += cast(Duration)(diff);
                }
                else
                {
                    std.stdio.writeln("nonlol-",num);
                }
            }

        );
    }
    } catch(Throwable e)
    {std.stdio.writeln(e);}
}

void cpuProcess(Duration ts, Input input)
{
    scope(failure) {std.stdio.writeln("Wasted!");}
    Thread.getThis.isDaemon = true;
    Tid[] discIds = [];
    try{
        while (true) {
            discIds ~= receiveOnly!Tid;
        }
    }
    catch(Exception e){}
    TickDuration startStamp = Clock.currAppTick;
    Duration loadTime = 0.dur!"msecs";
    while (true) {
        receive(
            (SubQuery q){
                loadTime += waitExp(ts);
                discIds[uniform(0,input.discsCount)].send(q);
            },
            (Tid asker){
                auto totalTime = cast(double)(cast(Duration)(Clock.currAppTick - startStamp)).total!"msecs";
                asker.send(loadTime.total!"msecs" / totalTime);   
            }
            );       
    }
}

void discProcess(Duration ts, Input input)
{
    scope(failure) {std.stdio.writeln("discWasted!");}
    Thread.getThis.isDaemon = true;
    Tid serverId = receiveOnly!Tid;
    TickDuration startStamp = Clock.currAppTick;
    Duration loadTime = 0.dur!"msecs";
    while(true)   
    {
        receive(
            (SubQuery sq)
            {
                loadTime += waitExp(ts);
                if(uniform!"[]"(0.0,1.0)<=input.requestProbability)
                    serverId.send(Query(sq.workstation, sq.server, sq.startStamp));
                else
                    serverId.send(SubQuery(sq.id, sq.workstation, sq.server, Clock.currAppTick));
            },
            (Tid asker){
                auto totalTime = cast(double)(cast(Duration)(Clock.currAppTick - startStamp)).total!"msecs";
                asker.send(loadTime.total!"msecs" / totalTime);   
            }
        );
    } 

}
    
Duration mapTime(double v)
{
    return dur!"msecs"(cast(long)v);
}

Output startSimulation(Input input, Duration maxSimTime)
{
    Tid[] workstations;
    foreach(i; 0..input.wokrstationsCount)
    {
        workstations ~= spawn(&workstationProcess, input.afterProcessTime.mapTime, input.queringProcessTime.mapTime, i, input.serversCount);
    }
    
    Tid[] servers;
    Tid[][] cpus;
    Tid[][] discs;
    foreach(i; 0..input.serversCount)
    {
        cpus~=[[]];
        discs~=[[]];
        Tid sid = spawn(&serverProcess, input);
        servers~=sid;
        foreach(j;0..input.discsCount)
        {
            Tid did = spawn(&discProcess,input.responseDiscTime.mapTime, input);
            discs[i]~=did;
            did.send(sid);
        }
        foreach(j;0..input.cpusCount)
        {
            Tid cid = spawn(&cpuProcess,input.responseProcessTime.mapTime, input);
            cpus[i]~= cid;
            foreach(d;discs[i])
                cid.send(d);
            cid.send(false);
        }
        foreach(cp;cpus[i])
            sid.send(cp);
        sid.send(false);
    }
    
    Tid cableProcessId = spawn(&cableProcess, input.sendingProcessTime.mapTime, cast(immutable)workstations, cast(immutable)servers);
    
    foreach(w; workstations) w.send(cableProcessId);
    foreach(s; servers) s.send(cableProcessId);
    
    Thread.sleep(maxSimTime);
    std.stdio.writeln("Simulation ended!");
    
    Tuple!(double, double, double)[] times;
    foreach(w; workstations)
    {
        w.send(thisTid);
        times ~= receiveOnly!(double, double, double);
    }
    auto wStat = times.mean;
    
    cableProcessId.send(thisTid);
    auto cableLoadFactor = receiveOnly!double();
    
    double[] serverTimes;
    foreach(s; servers)
    {
        s.send(thisTid);
        serverTimes ~= receiveOnly!double;
    }
    auto serverLoadFactor = serverTimes.mean;
    
    double[] cpuTimes;
    foreach(cp;cpus)
    {
        foreach(c;cp)
        {
            c.send(thisTid);
            cpuTimes~=receiveOnly!double;
        }
    }
    auto cpuLoadFactor = cpuTimes.mean;

    double[] discTimes;
    foreach(di;discs)
    {
        foreach(d;di)
        {
            d.send(thisTid);
            discTimes~=receiveOnly!double;
        }
    }
    auto discLoadFactor = discTimes.mean;    
    std.stdio.writeln(discTimes);

    Output output;
    output.systemResponseTime = wStat[0];
    output.workstationLoad = wStat[1];
    output.userLoad = wStat[2];
    output.cableLoad = cableLoadFactor;
    output.serverLoad = serverLoadFactor;
    output.discLoad=discLoadFactor;
    output.cpuLoad=cpuLoadFactor;
    
    return output;
}