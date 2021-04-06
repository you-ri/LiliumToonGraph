using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.UIElements;


[RequireComponent(typeof(LightingEnvironmentController))]
[RequireComponent(typeof(UIDocument))]
public class EnvironmentUI : MonoBehaviour
{
    LightingEnvironmentController _model;

    RadioButtonGroup _lightingEnvironmentGorup;

    RadioButtonGroup _cameraGorup;

    VisualElement _mainLightView;

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

        var lightingEnvironmentView = doc.rootVisualElement.Q("lightingenvironment-list-view");

        _lightingEnvironmentGorup = new RadioButtonGroup ();
        _lightingEnvironmentGorup.choices = _model.lightingEnvironments.Select ( t => t.name.Replace("Lighting Environment", ""));
        _lightingEnvironmentGorup.RegisterValueChangedCallback( e => LightingEnvironmentSelectionChanged(e.newValue));
        lightingEnvironmentView.Add(_lightingEnvironmentGorup);

        _lightingEnvironmentGorup.value = _model.currentIndex;

        _lightingEnvironemntAutoRotation = new Toggle("Auto Rotation");
        _lightingEnvironemntAutoRotation.RegisterValueChangedCallback( e => _model.autoRotation = e.newValue);
        lightingEnvironmentView.Add(_lightingEnvironemntAutoRotation);

        // Main Light
        _mainLightView = new VisualElement();
        var mainLightLabel = new Label("Main Light");
        mainLightLabel.AddToClassList("head1");
        _mainLightView.Add(mainLightLabel);

        _lightIntensity = new Slider(0,  3);
        _lightIntensity.label = "Intensity";
        _mainLightView.Add(_lightIntensity);
        _lightIntensity.RegisterValueChangedCallback( e => _model.mainLight.intensity = e.newValue);

        _lightYawAngle = new Slider(0,  360);
        _lightYawAngle.label = "Yaw";
        _mainLightView.Add(_lightYawAngle);
        _lightYawAngle.RegisterValueChangedCallback( e => LightYawChanged(e.newValue));

        _lightPitchAngle = new Slider(0, 180);
        _lightPitchAngle.label = "Pitch";
        _mainLightView.Add(_lightPitchAngle);
        _lightPitchAngle.RegisterValueChangedCallback( e => LightPitchChanged(e.newValue));

        lightingEnvironmentView.Add(_mainLightView);

        // Cameras
        _cameraGorup = new RadioButtonGroup ();
        _cameraGorup.choices = _model.cameras.Select ( t => t.name.Replace("CM vcam", ""));
        _cameraGorup.RegisterValueChangedCallback( e => CameraSelectionChanged(e.newValue));
        doc.rootVisualElement.Q("camera-list-view").Add(_cameraGorup);
        doc.rootVisualElement.Q("camera-list-view").style.display = _cameraGorup.choices.Count() != 0 ? DisplayStyle.Flex : DisplayStyle.None;

        _cameraGorup.value = _model.cameraIndex;

        // Objects
        foreach (var obj in _model.objects) {
            var objectsView = new VisualElement();
            var activationToggle = new Toggle(obj.name);
            activationToggle.SetValueWithoutNotify(obj.activeSelf);
            activationToggle.RegisterValueChangedCallback(e => obj.SetActive(!obj.gameObject.activeSelf));
            objectsView.Add(activationToggle);
 
            // Components
            var controlable = obj.GetComponent<ExposeBehaviour>();
            if (controlable != null) {
                var componentsView = new VisualElement();
                componentsView.style.marginLeft = 8;
                foreach (var eb in controlable.exposeBehaviours) {
                    if (eb.behaviour == null) continue;
                    var componentToggle = new Toggle(eb.name);
                    componentToggle.SetValueWithoutNotify(eb.behaviour.enabled);
                    componentToggle.RegisterValueChangedCallback(e => eb.behaviour.enabled = !eb.behaviour.enabled);
                    componentsView.Add(componentToggle);
                }
                objectsView.Add(componentsView);
            }
            doc.rootVisualElement.Q("object-list-view").Add(objectsView);
        }
        doc.rootVisualElement.Q("object-list-view").style.display = _model.objects.Length != 0 ? DisplayStyle.Flex : DisplayStyle.None;


    }

    void Update()
    {
        _lightingEnvironmentGorup.SetValueWithoutNotify(_model.currentIndex);
        _UpdateLightingEnvironmentIndex();

        _lightingEnvironemntAutoRotation.SetValueWithoutNotify(_model.autoRotation);


        if (_model.mainLight != null) {
            _lightIntensity.SetValueWithoutNotify(_model.mainLight.intensity);
            _lightYawAngle.SetValueWithoutNotify(_model.mainLight.transform.localRotation.eulerAngles.y);
            _lightPitchAngle.SetValueWithoutNotify((_model.mainLight.transform.localRotation.eulerAngles.x + 90) % 360);
            _mainLightView.SetEnabled(_model.mainLight.gameObject.activeInHierarchy);
        }

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
