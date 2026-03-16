
using UdonSharp;
using UnityEditor;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

namespace VRCVolumes
{
    public class BulkInstantiate : UdonSharpBehaviour
    {
        [Header("Config")]
        public int bulkAmount = 10;
        public GameObject item;

        [SerializeField, HideInInspector] 
        private GameObject bulkInstance;
        private GameObject queue;

        #if UNITY_EDITOR && !COMPILER_UDONSHARP
        public void Setup()
        {
            if (item == null)
                return;

            if (bulkInstance != null)
                DestroyImmediate(bulkInstance);
            
            bulkInstance = new GameObject();
            bulkInstance.transform.parent = transform;
            bulkInstance.name = "Queue";
            
            for (int i = 0; i < bulkAmount; i++)
                Instantiate(item, bulkInstance.transform).SetActive(false);
        }
        #endif

        private void Start() => CreateQueue();

        private void CreateQueue()
        {
            if (queue != null)
                Destroy(queue);
            queue = Instantiate(bulkInstance, transform);
        }

        public GameObject Spawn(Transform parent = null)
        {
            // If queue is empty we create a new one
            if (queue.transform.childCount == 0)
                CreateQueue();

            // Remove from queue and activate
            var child = queue.transform.GetChild(0);
            child.transform.parent = parent != null ? parent : transform;
            child.gameObject.SetActive(true);

            return child.gameObject;
        }
    }

    #if UNITY_EDITOR && !COMPILER_UDONSHARP
    [CustomEditor(typeof(BulkInstantiate))]
    class BulkInstantiateInspector : Editor
    {
        public override void OnInspectorGUI()
        {
            DrawDefaultInspector();

            BulkInstantiate instantiate = (BulkInstantiate)target;

            if (GUILayout.Button("Setup"))
                instantiate.Setup();
        }
    }
    #endif
}