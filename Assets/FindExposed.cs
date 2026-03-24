#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;
using System.Reflection;
using System.Collections.Generic;
using System;
using System.Threading;
using System.Threading.Tasks;
using System.Linq;
using VRC.Udon.Editor;
using HarmonyLib;

/// <summary>
/// You can get a list of exposed Udon methods by doing:
///   FindExposed.GetExposedTypeList()
/// </summary>
public class FindExposed
{
    /// <summary>
    /// This class was made in order to expose the 
    ///   com.vrchat.worlds/Integrations/UdonSharp/Editor/Compiler/Udon/CompilerUdonInterface.cs
    /// which is not accessible from outside of the module.
    /// </summary>
    public class CompilerUdonInterface
    {
        private readonly MethodInfo _GetUdonTypeName, _GetUdonMethodName, _GetUdonAccessorName, _IsExposedToUdon;
        private readonly object _FieldAccessorTypeGet, _FieldAccessorTypeSet;
        private static readonly CompilerUdonInterface _Self = new CompilerUdonInterface();

        public class FieldAccessorType
        {
            public static readonly FieldAccessorType Get = new FieldAccessorType(_Self._FieldAccessorTypeGet);
            public static readonly FieldAccessorType Set = new FieldAccessorType(_Self._FieldAccessorTypeSet);

            public readonly object value;

            private FieldAccessorType(object value)
            {
                this.value = value;
            }
        }

        public CompilerUdonInterface()
        { 
            var assembly = typeof(UdonSharp.Compiler.AssemblyDebugInfo).Assembly;
            var CompilerUdonInterface = assembly.GetType("UdonSharp.Compiler.Udon.CompilerUdonInterface");
            var FieldAccessorType = assembly.GetType("UdonSharp.Compiler.Udon.CompilerUdonInterface+FieldAccessorType");

            _GetUdonTypeName = CompilerUdonInterface.GetMethod("GetUdonTypeName", new Type[] { typeof(Type) });
            _GetUdonMethodName = CompilerUdonInterface.GetMethod("GetUdonMethodName", new Type[] { typeof(MethodInfo), typeof(Type) });
            _GetUdonAccessorName = CompilerUdonInterface.GetMethod("GetUdonAccessorName", new Type[] { typeof(FieldInfo), FieldAccessorType, typeof(Type) });
            _IsExposedToUdon = CompilerUdonInterface.GetMethod("IsExposedToUdon");

            _FieldAccessorTypeGet = FieldAccessorType.GetEnumValues().GetValue(0);
            _FieldAccessorTypeSet = FieldAccessorType.GetEnumValues().GetValue(1);
        }

        public static string GetUdonTypeName(Type externSymbol)
            => (string)_Self._GetUdonTypeName.Invoke(null, new object[] { externSymbol });

        public static string GetUdonMethodName(MethodInfo methodInfo)
            => (string)_Self._GetUdonMethodName.Invoke(null, new object[] { methodInfo, null });

        public static string GetUdonAccessorName(FieldInfo fieldInfo, FieldAccessorType accessorType)
            => (string)_Self._GetUdonAccessorName.Invoke(null, new object[] { fieldInfo, accessorType.value, null });

        public static bool IsExposedToUdon(string name)
            => (bool)_Self._IsExposedToUdon.Invoke(null, new object[] { name });
    }

    private static List<Type> GetNestedTypes(Type type)
    {
        List<Type> nestedTypes = new List<Type>();

        foreach (Type nestedType in type.GetNestedTypes())
        {
            nestedTypes.Add(nestedType);
            nestedTypes.AddRange(GetNestedTypes(nestedType));
        }

        return nestedTypes;
    }

    /// <summary>
    /// Returns a list of exposed Types (classes/enums) to Udon. If you wan't to get a list of methods you will 
    /// need to iterate over the Type's methods and check if they are exposed to Udon with:
    ///   CompilerUdonInterface.IsExposedToUdon(CompilerUdonInterface.GetUdonMethodName(methodInfo))
    /// 
    /// Original taken from: 
    ///   com.vrchat.worlds/Integrations/UdonSharp/Editor/Editors/UdonTypeExposureTree.cs BuildExposedTypeList()
    /// </summary>
    /// <returns></returns>
 
    public static List<Type> GetExposedTypeList()
    {
        int _assemblyCounter;
        List<Type> _exposedTypes = null;
        
        try
        {
            Assembly[] assemblies = AppDomain.CurrentDomain.GetAssemblies();

            object typeSetLock = new object();
            HashSet<Type> exposedTypeSet = new HashSet<Type>();
            
            int mainThreadID = Thread.CurrentThread.ManagedThreadId;
            _assemblyCounter = 0;
            int totalAssemblies = assemblies.Length;
            
            Parallel.ForEach(assemblies, new ParallelOptions { MaxDegreeOfParallelism = 3 }, assembly =>
            {
                if (assembly.FullName.Contains("UdonSharp") ||
                    assembly.FullName.Contains("CodeAnalysis"))
                    return;

                Interlocked.Increment(ref _assemblyCounter);

                if (Thread.CurrentThread.ManagedThreadId == mainThreadID) // Can only be called from the main thread, since Parallel.ForEach uses the calling thread for some loops we just only run this in that thread.
                    EditorUtility.DisplayProgressBar("Processing methods and types...", $"{_assemblyCounter}/{totalAssemblies}", _assemblyCounter / (float)totalAssemblies);

                Type[] assemblyTypes = assembly.GetTypes();

                List<Type> types = new List<Type>();

                foreach (Type assemblyType in assemblyTypes)
                {
                    types.Add(assemblyType);
                    types.AddRange(GetNestedTypes(assemblyType));
                }

                types = types.Distinct().ToList();

                HashSet<Type> localExposedTypeSet = new HashSet<Type>();

                foreach (Type type in types)
                {
                    if (type.IsByRef)
                        continue;

                    string typeName = CompilerUdonInterface.GetUdonTypeName(type);
                    if (UdonEditorManager.Instance.GetTypeFromTypeString(typeName) != null)
                    {
                        localExposedTypeSet.Add(type);

                        if (!type.IsGenericType && !type.IsGenericTypeDefinition)
                            localExposedTypeSet.Add(type.MakeArrayType());
                    }

                    MethodInfo[] methods = type.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static);

                    foreach (MethodInfo method in methods)
                    {
                        if (CompilerUdonInterface.IsExposedToUdon(CompilerUdonInterface.GetUdonMethodName(method)))
                        {
                            localExposedTypeSet.Add(method.DeclaringType);

                            // We also want to highlight types that can be returned or taken as parameters
                            if (method.ReturnType != typeof(void) &&
                                method.ReturnType.Name != "T" &&
                                method.ReturnType.Name != "T[]")
                            {
                                localExposedTypeSet.Add(method.ReturnType);

                                if (!method.ReturnType.IsArray && !method.ReturnType.IsGenericType &&
                                    !method.ReturnType.IsGenericTypeDefinition)
                                    localExposedTypeSet.Add(method.ReturnType.MakeArrayType());
                            }

                            foreach (ParameterInfo parameterInfo in method.GetParameters())
                            {
                                if (!parameterInfo.ParameterType.IsByRef)
                                {
                                    localExposedTypeSet.Add(parameterInfo.ParameterType);

                                    if (!parameterInfo.ParameterType.IsArray)
                                        localExposedTypeSet.Add(parameterInfo.ParameterType.MakeArrayType());
                                }
                            }
                        }
                    }

                    foreach (PropertyInfo property in type.GetProperties(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static))
                    {
                        MethodInfo propertyGetter = property.GetGetMethod();
                        if (propertyGetter == null)
                            continue;

                        if (CompilerUdonInterface.IsExposedToUdon(CompilerUdonInterface.GetUdonMethodName(propertyGetter)))
                        {
                            Type returnType = propertyGetter.ReturnType;

                            localExposedTypeSet.Add(property.DeclaringType);

                            if (returnType != typeof(void) &&
                                returnType.Name != "T" &&
                                returnType.Name != "T[]")
                            {
                                localExposedTypeSet.Add(returnType);

                                if (!returnType.IsArray && !returnType.IsGenericType &&
                                    !returnType.IsGenericTypeDefinition)
                                    localExposedTypeSet.Add(returnType.MakeArrayType());
                            }
                        }
                    }

                    foreach (FieldInfo field in type.GetFields(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static))
                    {
                        if (field.DeclaringType?.FullName ==
                            null) // Fix some weird types in Odin that don't have a name for their declaring type
                            continue;

                        if (CompilerUdonInterface.IsExposedToUdon(CompilerUdonInterface.GetUdonAccessorName(field, CompilerUdonInterface.FieldAccessorType.Get)))
                        {
                            Type returnType = field.FieldType;

                            localExposedTypeSet.Add(field.DeclaringType);

                            if (returnType != typeof(void) &&
                                returnType.Name != "T" &&
                                returnType.Name != "T[]")
                            {
                                localExposedTypeSet.Add(returnType);

                                if (!returnType.IsArray && !returnType.IsGenericType &&
                                    !returnType.IsGenericTypeDefinition)
                                    localExposedTypeSet.Add(returnType.MakeArrayType());
                            }
                        }
                    }
                }

                if (localExposedTypeSet.Count == 0) 
                    return;
                
                lock (typeSetLock)
                {
                    exposedTypeSet.UnionWith(localExposedTypeSet);
                }
            });

            _exposedTypes = exposedTypeSet.ToList();
        }
        finally
        {
            EditorUtility.ClearProgressBar();
        }

        _exposedTypes.RemoveAll(e => e.Name == "T" || e.Name == "T[]");
        
        return _exposedTypes;
    }

    [MenuItem("Find Exposed/Print Types")]
    public static void PrintTypes()
    {
        foreach(Type type in GetExposedTypeList())
            Debug.Log(type);
    }

    [MenuItem("Find Exposed/Print Methods")]
    public static void PrintMethods()
    {
        BindingFlags bindingFlags = BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static;

        foreach(Type type in GetExposedTypeList())
        {
            if (type.IsEnum)
                continue;
            
            foreach (MethodInfo method in type.GetMethods(bindingFlags).Where(e => !type.IsArray || e.Name != "Address"))
            {
                if (method.IsSpecialName && !method.Name.StartsWith("op_"))
                    continue;
                
                string methodName = CompilerUdonInterface.GetUdonMethodName(method);

                // This here is important, don't forget to check it!
                if (!CompilerUdonInterface.IsExposedToUdon(methodName))
                    continue;

                Debug.Log(method.FullDescription());
            }
        }
    }
}
#endif