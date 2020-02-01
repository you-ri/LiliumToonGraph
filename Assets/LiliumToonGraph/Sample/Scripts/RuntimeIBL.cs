using System.Collections;
using UnityEngine;

public class RuntimeIBL : MonoBehaviour
{
    [SerializeField] 
    private Material[] cubemaps;

    private ReflectionProbe _reflectionProbe;

    IEnumerator Start ()
    {
        RenderSettings.defaultReflectionMode = UnityEngine.Rendering.DefaultReflectionMode.Custom;
        _reflectionProbe = gameObject.AddComponent<ReflectionProbe> ();
        _reflectionProbe.cullingMask = 0;
        _reflectionProbe.mode = UnityEngine.Rendering.ReflectionProbeMode.Realtime;
        _reflectionProbe.refreshMode = UnityEngine.Rendering.ReflectionProbeRefreshMode.ViaScripting;
        _reflectionProbe.timeSlicingMode = UnityEngine.Rendering.ReflectionProbeTimeSlicingMode.NoTimeSlicing;

        for (int i = 0; ; i++) {
            UpdateEnvironment (cubemaps[i % cubemaps.Length]);
            yield return new WaitForSeconds (2);
        }
    }

    private void UpdateEnvironment (Material skybox)
    {
        RenderSettings.skybox = skybox;
        DynamicGI.UpdateEnvironment ();
        _reflectionProbe.RenderProbe ();
    }
}