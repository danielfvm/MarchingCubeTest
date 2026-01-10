using System.Collections.Generic;
using UdonSharp.Compiler.Assembly;
using UdonSharp.Compiler.Assembly.Instructions;

namespace UdonSharpOptimizer.Optimizations
{
    internal class OPTCopyLoad : BaseOptimization
    {
        protected override string GUILabel => "Copy Load";

        public override bool Enabled => OptimizerSettings.Instance.CopyAndLoad;

        public override void ProcessInstruction(Optimizer optimizer, List<AssemblyInstruction> instrs, int i)
        {
            // Remove Copy: Copy + Push
            if (instrs[i] is CopyInstruction cInst && i < instrs.Count - 1 && instrs[i + 1] is PushInstruction pInst)
            {
                if (Optimizer.IsPrivate(cInst.TargetValue) && cInst.TargetValue.UniqueID == pInst.PushValue.UniqueID && !optimizer.HasJump(pInst) && !optimizer.ReadScan(n => n == i + 1, cInst.TargetValue))
                {
                    instrs[i] = optimizer.TransferInstr(Optimizer.CopyComment("OPTCopyLoad", cInst), cInst);
                    instrs[i + 1] = optimizer.TransferInstr(new PushInstruction(cInst.SourceValue), pInst);
                    CountRemoved(optimizer, 3); // PUSH, PUSH, COPY
                }
            }
        }
    }
}
