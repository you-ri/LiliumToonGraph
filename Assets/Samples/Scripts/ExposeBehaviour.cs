using System.Collections;
using System.Collections.Generic;
using UnityEngine;



public class ExposeBehaviour : MonoBehaviour
{

    [System.Serializable]
    public struct Element
    {
        public string name;
        public Behaviour behaviour;

    }

    public Element[] exposeBehaviours;
}
