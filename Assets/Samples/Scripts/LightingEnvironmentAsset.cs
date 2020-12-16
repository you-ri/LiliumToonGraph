using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu()]
public class LightingEnvironmentAsset : ScriptableObject
{
    public Material skybox;

    public Color ambientColor = new Color(0.5f, 0.5f, 0.5f);

    public Color lightColor = Color.white;

    public float lightIntensity = 1;

    public Vector3 lightDirection = new Vector3(1, 1, 1);

}