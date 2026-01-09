public static class PersonExt
{
    public static string GetName(this Person self) => (string)((object[])(object)self)[0];
    public static int GetAge(this Person self) => (int)((object[])(object)self)[1];
}
  