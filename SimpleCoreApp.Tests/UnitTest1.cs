using System;
using Xunit;

namespace SimpleCoreApp.Tests
{
    public class UnitTest1
    {
        [Fact]
        public void Test1()
        {
            int x = 1;
            int y = 2;
            Assert.True(x + y == 3);
        }
    }
}
