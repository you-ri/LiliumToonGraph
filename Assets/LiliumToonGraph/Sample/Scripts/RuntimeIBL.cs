using System.Collections;
using UnityEngine;

public class RuntimeIBL : MonoBehaviour
{
    [SerializeField] 
    private Material[] cubemaps;

    private Cubemap _cubemap;

    private Camera _camera;

    IEnumerator Start ()
    {
        RenderSettings.defaultReflectionMode = UnityEngine.Rendering.DefaultReflectionMode.Custom;
        _cubemap = new Cubemap (64, TextureFormat.RGBA32, true);
        GameObject cubeMapCamera = new GameObject ("Environment Camera");
        cubeMapCamera.transform.position = Vector3.zero;
        cubeMapCamera.transform.rotation = Quaternion.identity;
        _camera = cubeMapCamera.AddComponent<Camera> ();
        _camera.allowHDR = true;
        _camera.cullingMask = 0;
        _camera.enabled = false;

        for (int i = 0; ; i++) {
            if (i >= cubemaps.Length) { i = 0; }

            UpdateEnvironment (cubemaps[i]);
            yield return new WaitForSeconds (2);
        }
    }

    private void Update ()
    {
        // UpdateEnvironment (cubemaps[0]);
    }

    private void OnDestroy ()
    {
        if (_camera != null) {
            Destroy (_camera.gameObject);
        }
        Destroy (_cubemap);
    }

    private void UpdateEnvironment (Material skybox)
    {
        RenderSettings.skybox = skybox;
        DynamicGI.UpdateEnvironment ();

        _camera.RenderToCubemap (_cubemap);
        RenderSettings.customReflection = _cubemap;
    }
}