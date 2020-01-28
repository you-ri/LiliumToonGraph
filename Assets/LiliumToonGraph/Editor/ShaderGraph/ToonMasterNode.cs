//
// based on: com.unity.shadergraph@7.1.2\Editor\Data\MasterNodes\PBRMasterNode.cs
//
using System;
using System.Linq;
using System.Collections.Generic;
using UnityEditor.Graphing;
using UnityEditor.ShaderGraph.Drawing;
using UnityEditor.ShaderGraph.Drawing.Controls;
using UnityEditor.ShaderGraph.Internal;
using UnityEngine;
using UnityEngine.UIElements;
using UnityEditor.ShaderGraph;

namespace LiliumEditor.Toon
{
    [Serializable]
    [Title ("Master", "Toon")]
    class ToonMasterNode : MasterNode<IToonSubShader>, IMayRequirePosition, IMayRequireNormal, IMayRequireTangent
    {
        public const string AlbedoSlotName = "Color";
        public const string EmissionSlotName = "Emission";
        public const string AlphaSlotName = "Alpha";
        public const string AlphaClipThresholdSlotName = "AlphaClipThreshold";
        public const string PositionName = "Vertex Position";
        public const string NormalName = "Vertex Normal";
        public const string TangentName = "Vertex Tangent";

        public const string ShadeSlotName = "OutlineColor";
        public const string ShadeShiftSlotName = "ShadeShift";
        public const string OutlineWidthSlotName = "OutlineWidth";
        public const string ToonyLightingSlotName = "ToonyLighting";

        public const int AlbedoSlotId = 0;
        public const int EmissionSlotId = 4;
        public const int AlphaSlotId = 7;
        public const int AlphaThresholdSlotId = 8;
        public const int PositionSlotId = 9;
        public const int VertNormalSlotId = 10;
        public const int VertTangentSlotId = 11;

        public const int ShadeSlotId = 12;
        public const int OutlineWidthSlotId = 15;
        public const int ToonyLightingSlotId = 16;
        public enum Model
        {
            Specular,
            Metallic
        }

        [SerializeField]
        Model m_Model = Model.Metallic;

        public Model model
        {
            get { return m_Model; }
            set {
                if (m_Model == value)
                    return;

                m_Model = value;
                UpdateNodeAfterDeserialization ();
                Dirty (ModificationScope.Topological);
            }
        }

        [SerializeField]
        SurfaceType m_SurfaceType;

        public SurfaceType surfaceType
        {
            get { return m_SurfaceType; }
            set {
                if (m_SurfaceType == value)
                    return;

                m_SurfaceType = value;
                Dirty (ModificationScope.Graph);
            }
        }

        [SerializeField]
        AlphaMode m_AlphaMode;

        public AlphaMode alphaMode
        {
            get { return m_AlphaMode; }
            set {
                if (m_AlphaMode == value)
                    return;

                m_AlphaMode = value;
                Dirty (ModificationScope.Graph);
            }
        }

        [SerializeField]
        bool m_TwoSided;

        public ToggleData twoSided
        {
            get { return new ToggleData (m_TwoSided); }
            set {
                if (m_TwoSided == value.isOn)
                    return;
                m_TwoSided = value.isOn;
                Dirty (ModificationScope.Graph);
            }
        }

        public ToonMasterNode ()
        {
            UpdateNodeAfterDeserialization ();
        }


        public sealed override void UpdateNodeAfterDeserialization ()
        {
            base.UpdateNodeAfterDeserialization ();
            name = "Toon Master";
            AddSlot (new PositionMaterialSlot (PositionSlotId, PositionName, PositionName, CoordinateSpace.Object, ShaderStageCapability.Vertex));
            AddSlot (new NormalMaterialSlot (VertNormalSlotId, NormalName, NormalName, CoordinateSpace.Object, ShaderStageCapability.Vertex));
            AddSlot (new TangentMaterialSlot (VertTangentSlotId, TangentName, TangentName, CoordinateSpace.Object, ShaderStageCapability.Vertex));
            AddSlot (new ColorRGBMaterialSlot (AlbedoSlotId, AlbedoSlotName, "Albedo", SlotType.Input, Color.grey.gamma, ColorMode.Default, ShaderStageCapability.Fragment));
            AddSlot (new ColorRGBMaterialSlot (ShadeSlotId, ShadeSlotName, ShadeSlotName, SlotType.Input, Color.gray, ColorMode.Default, ShaderStageCapability.Fragment));
            AddSlot (new ColorRGBMaterialSlot (EmissionSlotId, EmissionSlotName, EmissionSlotName, SlotType.Input, Color.black.gamma, ColorMode.Default, ShaderStageCapability.Fragment));
            AddSlot (new Vector1MaterialSlot (AlphaSlotId, AlphaSlotName, AlphaSlotName, SlotType.Input, 1f, ShaderStageCapability.Fragment));
            AddSlot (new Vector1MaterialSlot (AlphaThresholdSlotId, AlphaClipThresholdSlotName, AlphaClipThresholdSlotName, SlotType.Input, 0.5f, ShaderStageCapability.Fragment));
            AddSlot (new Vector1MaterialSlot (OutlineWidthSlotId, OutlineWidthSlotName, OutlineWidthSlotName, SlotType.Input, 1f, ShaderStageCapability.Vertex));

            // clear out slot names that do not match the slots
            // we support
            RemoveSlotsNameNotMatching (
                new[]
            {
                PositionSlotId,
                VertNormalSlotId,
                VertTangentSlotId,
                AlbedoSlotId,
                ShadeSlotId,
                EmissionSlotId,
                AlphaSlotId,
                AlphaThresholdSlotId,
                OutlineWidthSlotId,
            }, true);
        }

        protected override VisualElement CreateCommonSettingsElement ()
        {
            return new ToonSettingsView (this);
        }

        public NeededCoordinateSpace RequiresNormal (ShaderStageCapability stageCapability)
        {
            List<MaterialSlot> slots = new List<MaterialSlot> ();
            GetSlots (slots);

            List<MaterialSlot> validSlots = new List<MaterialSlot> ();
            for (int i = 0; i < slots.Count; i++) {
                if (slots[i].stageCapability != ShaderStageCapability.All && slots[i].stageCapability != stageCapability)
                    continue;

                validSlots.Add (slots[i]);
            }
            return validSlots.OfType<IMayRequireNormal> ().Aggregate (NeededCoordinateSpace.None, (mask, node) => mask | node.RequiresNormal (stageCapability));
        }

        public NeededCoordinateSpace RequiresPosition (ShaderStageCapability stageCapability)
        {
            List<MaterialSlot> slots = new List<MaterialSlot> ();
            GetSlots (slots);

            List<MaterialSlot> validSlots = new List<MaterialSlot> ();
            for (int i = 0; i < slots.Count; i++) {
                if (slots[i].stageCapability != ShaderStageCapability.All && slots[i].stageCapability != stageCapability)
                    continue;

                validSlots.Add (slots[i]);
            }
            return validSlots.OfType<IMayRequirePosition> ().Aggregate (NeededCoordinateSpace.None, (mask, node) => mask | node.RequiresPosition (stageCapability));
        }

        public NeededCoordinateSpace RequiresTangent (ShaderStageCapability stageCapability)
        {
            List<MaterialSlot> slots = new List<MaterialSlot> ();
            GetSlots (slots);

            List<MaterialSlot> validSlots = new List<MaterialSlot> ();
            for (int i = 0; i < slots.Count; i++) {
                if (slots[i].stageCapability != ShaderStageCapability.All && slots[i].stageCapability != stageCapability)
                    continue;

                validSlots.Add (slots[i]);
            }
            return validSlots.OfType<IMayRequireTangent> ().Aggregate (NeededCoordinateSpace.None, (mask, node) => mask | node.RequiresTangent (stageCapability));
        }
    }
}
