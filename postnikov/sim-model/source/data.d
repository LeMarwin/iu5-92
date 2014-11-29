module data;

import vibe.data.json;
import std.stdio;
import std.file;

struct Input
{
    size_t wokrstationsCount;
    size_t serversCount;
    size_t cpusCount;
    size_t discsCount;
    double afterProcessTime;
    double queringProcessTime;
    double responseProcessTime;
    double sendingProcessTime;
    double responseDiscTime;
    double requestProbability;
    
    static void genExample(string filename)
    {
        auto example = Input(8, 2, 2, 3, 80, 80, 10, 10, 10, 0.3).serializeToJson;
        auto builder = appender!string;
        
        writePrettyJsonString(builder, example);
        
        auto file = File(filename, "w");
        scope(exit) file.close();
        file.write(builder.data);
    }
}

struct Output
{
    double systemResponseTime;
    double workstationLoad;
    double cableLoad;
    double serverLoad;
    double userLoad;
    double discLoad;
    double cpuLoad;
    
    void save(string filename)
    {
        auto builder = appender!string;
        writePrettyJsonString(builder, this.serializeToJson);
        
        auto file = File(filename, "w");
        scope(exit) file.close();
        file.write(builder.data);
    }
    
    void toString(scope void delegate(const(char)[]) sink) const
    {
        writePrettyJsonString(sink, this.serializeToJson);
    }
}