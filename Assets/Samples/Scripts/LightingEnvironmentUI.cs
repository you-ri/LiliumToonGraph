using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UIElements;


[RequireComponent(typeof(LightingEnvironmentController))]
[RequireComponent(typeof(UIDocument))]
public class LightingEnvironmentUI : MonoBehaviour
{
    LightingEnvironmentController _model;

    RadioButtonGroup _lightingEnvironmentGorup;

    RadioButtonGroup _cameraGorup;

    VisualElement _prevSelectedRadioButton;

    VisualElement _prevCameraSectedRadioButton;

    Slider _lightYawAngle;

    Slider _lightPitchAngle;

    void OnEnable()
    {
        var doc = GetComponent<UIDocument>();
        _model = GetComponent<LightingEnvironmentController>();


        _lightingEnvironmentGorup = new RadioButtonGroup ();
        _lightingEnvironmentGorup.choices = _model.lightingEnvironments.Select ( t => t.name.Replace("Lighting Environment", ""));
        _lightingEnvironmentGorup.RegisterValueChangedCallback( e => LightingEnvironmentSelectionChanged(e.newValue));
        doc.rootVisualElement.Q("lightingenvironment-list-view").Add(_lightingEnvironmentGorup);

        _lightingEnvironmentGorup.value = _model.currentIndex;


        _cameraGorup = new RadioButtonGroup ();
        _cameraGorup.choices = _model.cameras.Select ( t => t.name.Replace("CM vcam", ""));
        _cameraGorup.RegisterValueChangedCallback( e => CameraSelectionChanged(e.newValue));
        doc.rootVisualElement.Q("camera-list-view").Add(_cameraGorup);

        doc.rootVisualElement.Q("lightingenvironment-list-view").Add(new Label("Main Light"));

        _lightYawAngle = new Slider(0,  360);
        _lightYawAngle.label = "Yaw";
        doc.rootVisualElement.Q("lightingenvironment-list-view").Add(_lightYawAngle);
        _lightYawAngle.RegisterValueChangedCallback( e => LightYawChanged(e.newValue));

        _lightPitchAngle = new Slider(0, 180);
        _lightPitchAngle.label = "Pitch";
        doc.rootVisualElement.Q("lightingenvironment-list-view").Add(_lightPitchAngle);
        _lightPitchAngle.RegisterValueChangedCallback( e => LightPitchChanged(e.newValue));

    }

    void Update()
    {
        _lightingEnvironmentGorup.SetValueWithoutNotify(_model.currentIndex);
        _UpdateLightingEnvironmentIndex();

        _lightYawAngle.SetValueWithoutNotify(_model.mainLight.transform.localRotation.eulerAngles.y);
        _lightPitchAngle.SetValueWithoutNotify((_model.mainLight.transform.localRotation.eulerAngles.x + 90) % 360);
    }

    void _UpdateLightingEnvironmentIndex()
    {
        var index = _lightingEnvironmentGorup.value;
        var selectedRadioButton = _lightingEnvironmentGorup.Children().First().Children().Skip(index).First();

        if (_prevSelectedRadioButton != null) {
            _prevSelectedRadioButton.RemoveFromClassList("selected");
        }
        selectedRadioButton.AddToClassList("selected");
        _prevSelectedRadioButton = selectedRadioButton;
    }

    void LightingEnvironmentSelectionChanged(int index)
    {
        _UpdateLightingEnvironmentIndex();

        if (_model.currentIndex != index) {
            _model.currentIndex = index;
            _model.duration = 0;
            _model.Apply();
        }

    }

    void _UpdateCameraIndex(int index)
    {
        var selectedRadioButton = _cameraGorup.Children().First().Children().Skip(index).First();

        if (_prevCameraSectedRadioButton != null) {
            _prevCameraSectedRadioButton.RemoveFromClassList("selected");
        }
        selectedRadioButton.AddToClassList("selected");
        _prevCameraSectedRadioButton = selectedRadioButton;
    }


    void CameraSelectionChanged(int index)
    {
        _UpdateCameraIndex(index);

        _model.cameraIndex = index;
        _model.ApplyCamera();
    }


    void LightYawChanged(float value)
    {
        var angles = _model.mainLight.transform.localRotation.eulerAngles;
        angles.y = value;
        angles.z = 0;
        _model.mainLight.transform.localRotation = Quaternion.Euler(angles);
    }

    void LightPitchChanged(float value)
    {
        value = (value + 360 - 90) % 360;

        var angles = _model.mainLight.transform.localRotation.eulerAngles;
        angles.x = value;
        angles.z = 0;
        _model.mainLight.transform.localRotation = Quaternion.Euler(angles);

    }
}
