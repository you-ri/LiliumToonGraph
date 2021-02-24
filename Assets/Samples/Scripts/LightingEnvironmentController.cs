using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Linq;
using UnityEngine.Rendering;


public class LightingEnvironmentController: MonoBehaviour
{
    public int currentIndex;

    public LightingEnvironmentAsset[] lightingEnvironments;

    public float duration = 2;

    private ReflectionProbe _reflectionProbe;

    private Light _mainLight;


    IEnumerator Start()
    {
        _reflectionProbe = gameObject.AddComponent<ReflectionProbe> ();
        _reflectionProbe.cullingMask = 0;
        _reflectionProbe.mode = UnityEngine.Rendering.ReflectionProbeMode.Realtime;
        _reflectionProbe.refreshMode = UnityEngine.Rendering.ReflectionProbeRefreshMode.ViaScripting;
        _reflectionProbe.timeSlicingMode = UnityEngine.Rendering.ReflectionProbeTimeSlicingMode.NoTimeSlicing;
        _reflectionProbe.size = new Vector3(100, 100, 100);
        currentIndex --;

        for (int i = 0; ; i++) {
            currentIndex = (++currentIndex) % lightingEnvironments.Length;
            Apply ();
            yield return new WaitForSeconds (duration);
        }
    }

    void OnDestroy() 
    {
        if (_reflectionProbe != null) {
            Destroy(_reflectionProbe);
        }
    }


    [ContextMenu("Apply")]
    public void Apply()
    {
        _mainLight = RenderSettings.sun;
        if (_mainLight == null) {
            _mainLight = FindObjectsOfType<Light>().OrderBy(t => -t.color.grayscale * t.intensity).FirstOrDefault();
        }
        if (_mainLight == null) {
            Debug.LogError("main light not found.");
            return;
        }

        var lightingEnvironment = lightingEnvironments.Skip(currentIndex).FirstOrDefault();

        if (lightingEnvironment == null) return;

        if (lightingEnvironment.skybox != null) {
            RenderSettings.ambientMode = AmbientMode.Skybox;
            RenderSettings.defaultReflectionMode = DefaultReflectionMode.Skybox;
            RenderSettings.skybox = lightingEnvironment.skybox;
        }
        else {
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.defaultReflectionMode = DefaultReflectionMode.Custom;
            RenderSettings.ambientLight = lightingEnvironment.ambientColor;
        }

        _mainLight.color = lightingEnvironment.lightColor;
        _mainLight.intensity = lightingEnvironment.lightIntensity;
        _mainLight.transform.rotation = Quaternion.FromToRotation(Vector3.forward, lightingEnvironment.lightDirection);

        DynamicGI.UpdateEnvironment ();

        if (Application.isPlaying) {
            RenderSettings.defaultReflectionMode = UnityEngine.Rendering.DefaultReflectionMode.Custom;
            _reflectionProbe.RenderProbe ();    
        }
    }


}
