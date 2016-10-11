using System;
using Xunit;

namespace Sharpflow.Client.Tests
{
    public class SimpleHttpClientTests
    {
#if NET35
        [Fact]
        public void GetTimeTest()
        {
            var client = new SimpleHttpClient();
            var time = client.GetTime();

            Console.WriteLine("GetTime: " + time);

            Assert.True(string.IsNullOrEmpty(time));
        }
#else
        [Fact]
        public void GetTimeAsyncTest()
        {
            var client = new SimpleHttpClient();
            var time = client.GetTimeAsync().Result;

            Console.WriteLine("GetTimeAsync: " + time);

            Assert.True(!string.IsNullOrEmpty(time));
        }
#endif
    }
}
