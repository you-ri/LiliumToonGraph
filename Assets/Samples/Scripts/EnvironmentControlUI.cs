using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UIElements;


[RequireComponent(typeof(LightingEnvironmentController))]
[RequireComponent(typeof(UIDocument))]
public class EnvironmentControlUI : MonoBehaviour
{
    LightingEnvironmentController _model;

    RadioButtonGroup _lightingEnvironmentGorup;

    RadioButtonGroup _cameraGorup;

    Toggle _lightingEnvironemntAutoRotation;

    VisualElement _prevSelectedRadioButton;

    VisualElement _prevCameraSectedRadioButton;

    Slider _lightIntensity;

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

        _cameraGorup.value = _model.cameraIndex;


        _lightingEnvironemntAutoRotation = new Toggle("Auto Rotation");
        _lightingEnvironemntAutoRotation.RegisterValueChangedCallback( e => _model.autoRotation = e.newValue);
        doc.rootVisualElement.Q("lightingenvironment-list-view").Add(_lightingEnvironemntAutoRotation);

        var mainLightLabel = new Label("Main Light");
        mainLightLabel.AddToClassList("head1");
        doc.rootVisualElement.Q("lightingenvironment-list-view").Add(mainLightLabel);

        _lightIntensity = new Slider(0,  3);
        _lightIntensity.label = "Intensity";
        doc.rootVisualElement.Q("lightingenvironment-list-view").Add(_lightIntensity);
        _lightIntensity.RegisterValueChangedCallback( e => _model.mainLight.intensity = e.newValue);

        _lightYawAngle = new Slider(0,  360);
        _lightYawAngle.label = "Yaw";
        doc.rootVisualElement.Q("lightingenvironment-list-view").Add(_lightYawAngle);
        _lightYawAngle.RegisterValueChangedCallback( e => LightYawChanged(e.newValue));

        _lightPitchAngle = new Slider(0, 180);
        _lightPitchAngle.label = "Pitch";
        doc.rootVisualElement.Q("lightingenvironment-list-view").Add(_lightPitchAngle);
        _lightPitchAngle.RegisterValueChangedCallback( e => LightPitchChanged(e.newValue));

        foreach (var obj in _model.objects) {
            var activationToggle = new Toggle(obj.name);
            activationToggle.SetValueWithoutNotify(obj.activeSelf);
            activationToggle.RegisterValueChangedCallback(e => obj.SetActive(!obj.activeSelf));
            doc.rootVisualElement.Q("object-list-view").Add(activationToggle);
        }


    }

    void Update()
    {
        _lightingEnvironmentGorup.SetValueWithoutNotify(_model.currentIndex);
        _UpdateLightingEnvironmentIndex();

        _lightingEnvironemntAutoRotation.SetValueWithoutNotify(_model.autoRotation);
        _lightIntensity.SetValueWithoutNotify(_model.mainLight.intensity);
        _lightYawAngle.SetValueWithoutNotify(_model.mainLight.transform.localRotation.eulerAngles.y);
        _lightPitchAngle.SetValueWithoutNotify((_model.mainLight.transform.localRotation.eulerAngles.x + 90) % 360);

        _cameraGorup.SetValueWithoutNotify(_model.cameraIndex);
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
            _model.autoRotation = false;
            _model.Apply();
        }

    }

    void _UpdateCameraIndex(int index)
    {
        if (_cameraGorup.Children().First().Children().Count() <= index) return;
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
