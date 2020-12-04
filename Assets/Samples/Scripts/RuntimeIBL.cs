using System.Collections;
using UnityEngine;
using System.Linq;

public class RuntimeIBL : MonoBehaviour
{
    [System.Serializable]
    public struct Environment
    {
        public Material skybox;
        public Color lightColor;

        public float intensity;
    }

    public Light mainLight;

    public float duration = 2;

    [SerializeField] 
    private Environment[] _environments = null;

    private ReflectionProbe _reflectionProbe;

    void Reset() 
    {
        mainLight = FindObjectsOfType<Light>().OrderBy(t => -t.color.grayscale * t.intensity).FirstOrDefault();
    }

    IEnumerator Start ()
    {
        RenderSettings.defaultReflectionMode = UnityEngine.Rendering.DefaultReflectionMode.Custom;
        _reflectionProbe = gameObject.AddComponent<ReflectionProbe> ();
        _reflectionProbe.cullingMask = 0;
        _reflectionProbe.mode = UnityEngine.Rendering.ReflectionProbeMode.Realtime;
        _reflectionProbe.refreshMode = UnityEngine.Rendering.ReflectionProbeRefreshMode.ViaScripting;
        _reflectionProbe.timeSlicingMode = UnityEngine.Rendering.ReflectionProbeTimeSlicingMode.NoTimeSlicing;

        for (int i = 0; ; i++) {
            UpdateEnvironment (_environments[i % _environments.Length]);
            yield return new WaitForSeconds (duration);
        }
    }

    void OnDestroy() 
    {
        if (_reflectionProbe != null) {
            Destroy(_reflectionProbe);
        }
    }

    private void UpdateEnvironment (Environment environment)
    {
        RenderSettings.skybox = environment.skybox;
        mainLight.color = environment.lightColor;
        mainLight.intensity = environment.intensity;
        DynamicGI.UpdateEnvironment ();
        _reflectionProbe.RenderProbe ();
    }
}