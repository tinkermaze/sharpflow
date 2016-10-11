#if NET35
using System.Net;
#else
using System.Net.Http;
using System.Threading.Tasks;
#endif
using Newtonsoft.Json.Linq;

namespace Sharpflow.Client
{
    public class SimpleHttpClient
    {
        public const string TimeApiEndpoint = "http://www.timeapi.org/utc/now.json";

#if NET35
        private readonly WebClient client = new WebClient();
#else
        private readonly HttpClient client = new HttpClient();
#endif

#if NET35
        public string GetTime()
        {
            var response = client.DownloadString(TimeApiEndpoint);
            return (string)JObject.Parse(response)["dateString"];
        }
#else
        public async Task<string> GetTimeAsync()
        {
            var response = await client.GetStringAsync(TimeApiEndpoint);
            return (string)JObject.Parse(response)["dateString"];
        }
#endif
    }
}
