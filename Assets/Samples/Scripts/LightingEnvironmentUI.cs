using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UIElements;


[RequireComponent(typeof(LightingEnvironmentController))]
[RequireComponent(typeof(UIDocument))]
public class LightingEnvironmentUI : MonoBehaviour
{
    RadioButtonGroup _gorup;

    VisualElement _prevSelectedRadioButton;
    

    LightingEnvironmentController _model;
    void OnEnable()
    {
        var doc = GetComponent<UIDocument>();
        _model = GetComponent<LightingEnvironmentController>();

        var topView = doc.rootVisualElement.Q("top-view");

        _gorup = new RadioButtonGroup ();
        _gorup.choices = _model.lightingEnvironments.Select ( t => t.name.Replace("Lighting Environment", ""));
        _gorup.RegisterValueChangedCallback( e => LightingEnvironmentSelectionChanged(e.newValue));
        topView.Add(_gorup);

        _gorup.value = _model.currentIndex;
    }

    void Update()
    {
        _gorup.SetValueWithoutNotify(_model.currentIndex);
        _UpdateValueChanged();
    }

    void _UpdateValueChanged()
    {
        var index = _gorup.value;
        var selectedRadioButton = _gorup.Children().First().Children().Skip(index).First();

        if (_prevSelectedRadioButton != null) {
            _prevSelectedRadioButton.RemoveFromClassList("selected");
        }
        selectedRadioButton.AddToClassList("selected");
        _prevSelectedRadioButton = selectedRadioButton;
    }

    void LightingEnvironmentSelectionChanged(int index)
    {
        _UpdateValueChanged();

        if (_model.currentIndex != index) {
            _model.currentIndex = index;
            _model.duration = 0;
            _model.Apply();
        }

    }

}
